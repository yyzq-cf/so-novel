# syntax=docker/dockerfile:1
# 多架构多阶段构建。
# builder 阶段用 --platform=$TARGETPLATFORM：buildx 通过 QEMU 在目标架构下运行 Maven，
# pom.xml 的 OS-activated profile 会自动识别 os.arch 拉入对应 javet V8 native 库。

# ====== Stage 1: build (per-target-arch native build) ======
FROM maven:3.9-eclipse-temurin-21 AS builder

WORKDIR /build

# 先只拷 pom.xml 预下载公共依赖（加速 + 缓存友好）
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 \
    mvn -q dependency:go-offline -Dmaven.test.skip=true || true

# 拷源码编译
COPY src ./src
COPY bundle ./bundle
COPY assets ./assets

# 编译打包。QEMU 下 OS profile 按 TARGETPLATFORM 自动激活 javet native 库
# -Dlaunch4j.skip: 跳过 Windows .exe 生成（launch4j 的 windres 只有 amd64 版，
#   arm64 下会找不到二进制；Docker 里只需要 jar）
# -DjrePath=runtime: 满足 pom 中 ${jrePath} 引用，避免 launch4j 配置解析报错
RUN --mount=type=cache,target=/root/.m2 \
    mvn -q clean package -Dmaven.test.skip=true \
        -Dlaunch4j.skip=true -DjrePath=runtime

# 整理产物
RUN mkdir -p /out && \
    cp target/app-jar-with-dependencies.jar /out/app.jar && \
    cp bundle/config.ini /out/ && \
    cp -r bundle/rules /out/

# ====== Stage 2: runtime (glibc base for javet libjavet.so) ======
FROM eclipse-temurin:21-jre-jammy

WORKDIR /sonovel

COPY --from=builder /out/app.jar /out/config.ini ./
COPY --from=builder /out/rules/ rules/

EXPOSE 7765

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS \
  -XX:+UseZGC \
  -XX:+ZGenerational \
  -Dfile.encoding=UTF-8 \
  -Duser.timezone=GMT+08 \
  -jar app.jar"]
