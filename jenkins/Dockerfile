FROM jenkins:alpine
USER root
RUN set -xe \
  && echo 'http://mirrors.aliyun.com/alpine/latest-stable/main' > /etc/apk/repositories \
  && echo '@community http://mirrors.aliyun.com/alpine/latest-stable/community' >> /etc/apk/repositories \
  && ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime \
  && echo "Asia/Shanghai" >  /etc/timezone \
  && apk add --update rsync 
USER jenkins