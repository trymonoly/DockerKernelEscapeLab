FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libcap2-bin \
        nftables \
        util-linux \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/lab
COPY scripts/audit.sh scripts/af_alg_probe.py /opt/lab/scripts/
RUN chmod 0555 /opt/lab/scripts/audit.sh /opt/lab/scripts/af_alg_probe.py

ENV HOME=/tmp
USER 1000:1000

CMD ["/opt/lab/scripts/audit.sh"]
