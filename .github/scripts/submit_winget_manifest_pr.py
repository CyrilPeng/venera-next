import argparse
import json
import subprocess
from pathlib import Path


class WingetPrError(RuntimeError):
    pass


def gh_api(repo_path: str, method: str = "GET", data: dict | None = None):
    command = ["gh", "api", repo_path, "--method", method]
    payload = None
    if data is not None:
        command += ["--input", "-"]
        payload = json.dumps(data)
    result = subprocess.run(
        command,
        input=payload,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        message = (result.stderr or result.stdout).strip()
        raise WingetPrError(message)
    output = result.stdout or ""
    if not output.strip():
        return None
    return json.loads(output)


def manifest_files(manifest_root: Path, version: str) -> list[Path]:
    source = manifest_root / "c" / "CyrilPeng" / "VeneraNext" / version
    if not source.is_dir():
        raise WingetPrError(f"manifest directory does not exist: {source}")
    files = sorted(source.glob("*.yaml"))
    if len(files) != 3:
        raise WingetPrError(f"expected 3 winget manifest files, found {len(files)}")
    return files


def create_or_update_branch(
    fork_repo: str,
    base_branch: str,
    branch: str,
    files: list[Path],
    version: str,
) -> str:
    base_ref = gh_api(f"repos/{fork_repo}/git/ref/heads/{base_branch}")
    base_sha = base_ref["object"]["sha"]
    base_commit = gh_api(f"repos/{fork_repo}/git/commits/{base_sha}")
    base_tree = base_commit["tree"]["sha"]

    try:
        gh_api(
            f"repos/{fork_repo}/git/refs",
            "POST",
            {"ref": f"refs/heads/{branch}", "sha": base_sha},
        )
    except WingetPrError as error:
        if "Reference already exists" not in str(error):
            raise

    entries = []
    for file in files:
        blob = gh_api(
            f"repos/{fork_repo}/git/blobs",
            "POST",
            {"content": file.read_text(encoding="utf-8"), "encoding": "utf-8"},
        )
        entries.append(
            {
                "path": (
                    "manifests/c/CyrilPeng/VeneraNext/"
                    f"{version}/{file.name}"
                ),
                "mode": "100644",
                "type": "blob",
                "sha": blob["sha"],
            },
        )

    tree = gh_api(
        f"repos/{fork_repo}/git/trees",
        "POST",
        {"base_tree": base_tree, "tree": entries},
    )
    commit = gh_api(
        f"repos/{fork_repo}/git/commits",
        "POST",
        {
            "message": f"New version: CyrilPeng.VeneraNext version {version}",
            "tree": tree["sha"],
            "parents": [base_sha],
        },
    )
    gh_api(
        f"repos/{fork_repo}/git/refs/heads/{branch}",
        "PATCH",
        {"sha": commit["sha"], "force": True},
    )
    return commit["sha"]


def existing_pr(upstream_repo: str, head: str):
    prs = gh_api(
        f"repos/{upstream_repo}/pulls?head={head}&state=open",
    )
    return prs[0] if prs else None


def create_pr(
    upstream_repo: str,
    fork_owner: str,
    branch: str,
    base_branch: str,
    version: str,
) -> str:
    head = f"{fork_owner}:{branch}"
    current = existing_pr(upstream_repo, head)
    if current is not None:
        return current["html_url"]
    pr = gh_api(
        f"repos/{upstream_repo}/pulls",
        "POST",
        {
            "title": f"New version: CyrilPeng.VeneraNext version {version}",
            "head": head,
            "base": base_branch,
            "body": (
                f"- Adds CyrilPeng.VeneraNext {version}\n"
                "- Generated from the venera-next release workflow artifact.\n"
            ),
        },
    )
    return pr["html_url"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--manifest-root", type=Path, required=True)
    parser.add_argument("--fork-repo", default="CyrilPeng/winget-pkgs")
    parser.add_argument("--upstream-repo", default="microsoft/winget-pkgs")
    parser.add_argument("--base-branch", default="master")
    parser.add_argument("--branch")
    args = parser.parse_args()

    try:
        branch = args.branch or f"cyrilpeng-veneranext-{args.version}"
        files = manifest_files(args.manifest_root, args.version)
        create_or_update_branch(
            args.fork_repo,
            args.base_branch,
            branch,
            files,
            args.version,
        )
        fork_owner = args.fork_repo.split("/", 1)[0]
        url = create_pr(
            args.upstream_repo,
            fork_owner,
            branch,
            args.base_branch,
            args.version,
        )
        print(url)
    except WingetPrError as error:
        print(f"::error::{error}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
