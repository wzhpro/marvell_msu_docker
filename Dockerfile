FROM fedora:31
RUN yum install -y \
	unzip \
	libxcrypt-compat \
	libnsl \
	procps \
	wget \
	dash

COPY entrance.sh .
# https://download.lenovo.com/servers/mig/2019/04/11/19912/mrvl_utl_msu_4.1.10.2046_linux_x86-64.tgz 
COPY MSU-4.1.10.2046-1.x86_64.rpm .
RUN yum install -y MSU-4.1.10.2046-1.x86_64.rpm
RUN rm -rf MSU-4.1.10.2046-1.x86_64.rpm
# redirect config db.xml
RUN mv /opt/marvell/storage/db/db.xml /opt/marvell/storage/db/db.xml.orig && \
	ln -s /etc/marvell/db.xml /opt/marvell/storage/db/db.xml

# redirect logs from raid controller
RUN rm /opt/marvell/storage/db/mvraidsvc.log && \
	ln -s /dev/stdout /opt/marvell/storage/db/mvraidsvc.log


EXPOSE 8845/tcp

ENTRYPOINT ["/entrance.sh"]
