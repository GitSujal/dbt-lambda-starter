import os
import multiprocessing
import threading
import dbt.adapters.base


# Patch multiprocessing for Lambda environment where /dev/shm is missing
def patch_multiprocessing():
    import multiprocessing.synchronize

    class MockRLock:
        def __init__(self, *args, **kwargs):
            self._lock = threading.RLock()

        def __enter__(self):
            return self._lock.__enter__()

        def __exit__(self, *args):
            return self._lock.__exit__(*args)

        def acquire(self, *args, **kwargs):
            return self._lock.acquire(*args, **kwargs)

        def release(self):
            return self._lock.release()

        def _is_owned(self):
            return True

    class MockLock:
        def __init__(self, *args, **kwargs):
            self._lock = threading.Lock()

        def __enter__(self):
            return self._lock.__enter__()

        def __exit__(self, *args):
            return self._lock.__exit__(*args)

        def acquire(self, *args, **kwargs):
            return self._lock.acquire(*args, **kwargs)

        def release(self):
            return self._lock.release()

    class MockSemaphore:
        def __init__(self, value=1, *args, **kwargs):
            self._sem = threading.Semaphore(value)

        def __enter__(self):
            return self._sem.__enter__()

        def __exit__(self, *args):
            return self._sem.__exit__(*args)

        def acquire(self, *args, **kwargs):
            return self._sem.acquire(*args, **kwargs)

        def release(self):
            return self._sem.release()

    class MockBoundedSemaphore:
        def __init__(self, value=1, *args, **kwargs):
            self._sem = threading.BoundedSemaphore(value)

        def __enter__(self):
            return self._sem.__enter__()

        def __exit__(self, *args):
            return self._sem.__exit__(*args)

        def acquire(self, *args, **kwargs):
            return self._sem.acquire(*args, **kwargs)

        def release(self):
            return self._sem.release()

    multiprocessing.synchronize.RLock = MockRLock
    multiprocessing.synchronize.Lock = MockLock
    multiprocessing.synchronize.Semaphore = MockSemaphore
    multiprocessing.synchronize.BoundedSemaphore = MockBoundedSemaphore


patch_multiprocessing()

# Shim for Credentials import error in newer dbt versions
try:
    from dbt.adapters.base import Credentials
except ImportError:
    try:
        from dbt.adapters.contracts.connection import Credentials

        dbt.adapters.base.Credentials = Credentials
    except ImportError:
        pass

from dbt.cli.main import dbtRunner, dbtRunnerResult

# Ensure writable directories exist
os.makedirs("/tmp/logs", exist_ok=True)
os.makedirs("/tmp/target", exist_ok=True)

# Set environment variables for dbt to use /tmp
os.environ["DBT_LOG_PATH"] = "/tmp/logs"
os.environ["DBT_TARGET_PATH"] = "/tmp/target"
os.environ["DBT_PROFILES_DIR"] = "."
os.environ["DBT_USER_CONFIG_DIR"] = "/tmp"

# initialize
dbt = dbtRunner()

# create CLI args as a list of strings
default_args = [
    "--target",
    "dev",
    "--log-path",
    "/tmp/logs",
    "--target-path",
    "/tmp/target",
    "--target",
    os.getenv("ENVIRONMENT", "dev"),
    "--profiles-dir",
    ".",
]


def handler(event, context):
    """
    AWS Lambda handler to run dbt commands.
    1. Parses event for dbt command and CLI args.
    2. Invokes dbt with specified command and args.
    3. Returns success or failure response.
    4. Logs output to /tmp/logs and /tmp/target.
    5. Raises exception on failure.
    6. Default command is 'build' with selection of 'my_second_dbt_model

    Event example::
    {
        "command": ["build"],
        "cli_args": ["--select", "+my_second_dbt_model"]
    }

    Another example:
    {
        "command": ["run"],
        "cli_args": ["--select", "my_dbt_model"]
    }

    """
    print("Event:", event)
    print("Context:", context)

    # Prepare CLI arguments
    command = event.get("command", ["build"])
    cli_args = event.get("cli_args", ["--select", "+my_second_dbt_model"])

    # Run dbt build command
    res: dbtRunnerResult = dbt.invoke(command + default_args + cli_args)

    if res.success:
        print("DBT build succeeded")
    else:
        print("DBT build failed")
        raise Exception("DBT build failed")

    return {"statusCode": 200 if res.success else 500, "body": "DBT build completed"}


if __name__ == "__main__":
    # For local testing
    test_event = {
        "command": ["build"],
        "cli_args": ["--select", "+my_second_dbt_model"],
    }
    test_context = {}
    handler(test_event, test_context)
