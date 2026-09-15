FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server nginx python3 cmake build-essential git wget curl ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn \
    && cd /tmp/badvpn && mkdir build && cd build \
    && cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 \
        -DCMAKE_INSTALL_PREFIX=/usr/local/impostor \
    && make install && rm -rf /tmp/badvpn

RUN mkdir -p /var/run/sshd
RUN useradd -m -s /bin/bash Impostor \
    && echo "Impostor:Impostor" | chpasswd

RUN sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/^#PasswordAuthentication/PasswordAuthentication/' /etc/ssh/sshd_config
RUN sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

RUN echo "UseDNS no;" >> /etc/ssh/sshd_config \
    && echo "TCPKeepAlive yes;" >> /etc/ssh/sshd_config \
    && echo "ClientAliveInterval 15;" >> /etc/ssh/sshd_config \
    && echo "ClientAliveCountMax 3;" >> /etc/ssh/sshd_config \
    && echo "MaxSessions 50;" >> /etc/ssh/sshd_config \
    && echo "MaxStartups 50:30:100;" >> /etc/ssh/sshd_config \
    && echo "Compression no;" >> /etc/ssh/sshd_config

COPY banner.txt /etc/banner.txt
RUN echo "Banner /etc/banner.txt" >> /etc/ssh/sshd_config

COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22 7300 8080

ENTRYPOINT ["/entrypoint.sh"]
