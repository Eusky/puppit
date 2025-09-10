# 베이스 이미지
FROM ubuntu:22.04

# 이미지 빌드 시 실행할 명령어 (패키지 설치)
RUN apt update && apt install -y openjdk-11-jdk wget git maven mysql-server nginx

# 이미지 빌드 시 실행할 명령어 톰캣 9.0 설치
RUN wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.109/bin/apache-tomcat-9.0.109.tar.gz -P /home/tomcat
RUN tar -xzvf /home/tomcat/apache-tomcat-9.0.109.tar.gz -C /home/tomcat

# index.html 파일을 이미지 내부 톰캣 9.0 배포 경로로 복사
COPY index.html /home/tomcat/apache-tomcat-9.0.109/webapps/ROOT/index.html

# 이미지 빌드와 컨테이너 실행 시 사용할 수 있는 환경 변수 (JAVA_HOME, aws_region) 
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV AWS_REGION=ap-northeast-2

# 이미지 빌드 시 실행할 명령어 (MySQL 설정 및 시작)
RUN service mysql start && \
    mysql -e "CREATE DATABASE IF NOT EXISTS db_puppit;" && \
    mysql -e "CREATE USER 'user'@'localhost' IDENTIFIED BY 'user';" && \
    mysql -e "GRANT ALL PRIVILEGES ON db_puppit.* TO 'user'@'localhost';" && \
    mysql -e "FLUSH PRIVILEGES;" && \
    service mysql stop

# 기본 작업 경로 설정 (github 소스코드 클론할 경로)
WORKDIR /tmp

# 이미지 빌드 시 실행할 명령어 (github 소스코드 클론)
RUN git clone https://github.com/choimeeyoung94/puppit.git

# 기존 작업 경로 설정 (maven 빌드할 경로)
WORKDIR /tmp/puppit

# 이미지 빌드 시 실행할 명령어 (maven 빌드)
RUN mvn clean package

# 이미지 빌드 시 실행할 명령어 (빌드 결과 war 파일을 톰캣 9.0에 배포)
RUN cp /tmp/puppit/target/*.war /home/tomcat/apache-tomcat-9.0.109/webapps/puppit.war


# 이미지 빌드 시 실행할 명령어 (nginx 리버스 프록시 설정)
RUN cat > /etc/nginx/conf.d/tomcat-proxy.conf << 'EOF'
server {
    listen 80;
    server_name localhost 127.0.0.1 192.168.56.1 _;
    location /puppit {
        proxy_pass http://localhost:8080/puppit;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# 포트 열기 (톰캣, MySQL 포트 열기)
EXPOSE 8080 3306

RUN echo '#!/bin/bash' > /home/start.sh && \
    echo 'echo "Start MySQL Server ..."' >> /home/start.sh && \
    echo 'service mysql start' >> /home/start.sh && \
    echo 'echo "Running schema.sql ..."' >> /home/start.sh && \
    echo 'mysql -u user -ppuppitgood db_puppit < /tmp/puppit/src/main/resources/schema.sql' >> /home/start.sh && \
    echo 'echo "Start Tomcat Server ..."' >> /home/start.sh && \
    echo '/home/tomcat/apache-tomcat-9.0.109/bin/catalina.sh start' >> /home/start.sh && \
    echo 'echo "Start Nginx server ..."' >> /home/start.sh && \
    echo 'nginx -g "daemon off;"' >> /home/start.sh


# 이미지 빌드 시 실행할 명령어 (/home/start.sh 파일에 실행 권한 부여하기)
RUN chmod a+x /home/start.sh

# 컨테이너 실행 시 수행할 명령어
CMD ["/home/start.sh"]

