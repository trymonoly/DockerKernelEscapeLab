import socket


def main():
    try:
        sock = socket.socket(socket.AF_ALG, socket.SOCK_SEQPACKET, 0)
        print("AF_ALG_SOCKET=OK")
    except OSError as exc:
        print(f"AF_ALG_SOCKET=FAIL errno={exc.errno} ({exc.strerror})")
        return

    try:
        sock.bind(("aead", "gcm(aes)", 0))
        print("AEAD_BIND=OK")
    except OSError as exc:
        print(f"AEAD_BIND=FAIL errno={exc.errno} ({exc.strerror})")
    finally:
        sock.close()


if __name__ == "__main__":
    main()
