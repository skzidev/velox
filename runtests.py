import subprocess


def readLine(line: str):
    pass


def main():
    with subprocess.Popen(
        ["cargo-v5", "v5", "terminal"], stdout=subprocess.PIPE, text=True
    ) as process:
        if process.stdout == None:
            print("failed to open serial terminal")
            return
        for line in process.stdout:
            readLine(line)
            print(line, end="", flush=True)


if __name__ == "__main__":
    main()
