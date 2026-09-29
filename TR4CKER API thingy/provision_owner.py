from __future__ import annotations

import getpass
import uuid
from pathlib import Path

from dotenv import load_dotenv

from auth_security import hash_password
from auth_store import AuthStore


def main() -> int:
    load_dotenv(Path(__file__).with_name(".env"))
    username = input("Owner username: ").strip()
    if not 1 <= len(username) <= 64:
        print("Username must be between 1 and 64 characters.")
        return 1

    password = getpass.getpass("Owner password (6-256 characters): ")
    if not 6 <= len(password) <= 256:
        print("Password must be between 6 and 256 characters.")
        return 1
    if password != getpass.getpass("Confirm owner password: "):
        print("Passwords do not match.")
        return 1

    created = AuthStore.from_environment().create_initial_owner(
        user_id=str(uuid.uuid4()),
        username=username,
        password_hash=hash_password(password),
    )
    if not created:
        print("An account already exists; owner provisioning is closed.")
        return 1
    print("Owner account created. Sign in through the SkyForge app.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())