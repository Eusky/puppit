# ---- Build stage ----
FROM maven:3.9.6-eclipse-temurin-11 AS build
WORKDIR /app
# 소스 복사 (Git 클론 대신, 로컬/CI 컨텍스트 복사 권장)
COPY . .
RUN mvn -DskipTests package

# ---- Runtime stage ----
FROM tomcat:9.0.89-jdk11-temurin

# 타임존/로케일
ENV TZ=Asia/Seoul LANG=ko_KR.UTF-8

# 컨텍스트 경로 선택:
# 루트(/)로 서비스하려면 ROOT.war 사용
COPY --from=build /app/target/*.war /usr/local/tomcat/webapps/ROOT.war


EXPOSE 8080
CMD ["catalina.sh","run"]
