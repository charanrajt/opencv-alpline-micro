FROM alpine:3.5
LABEL maintainer "charanrajt@gmail.com"
ENV OPENCV_VERSION 3.4.5



#2 Add Edge and bleeding repos
# add the edge repositories
RUN echo "@edge-testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
echo "@edge-community http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories




RUN addgroup -S redis && adduser -S -G redis redis

RUN apk add --no-cache \
# grab su-exec for easy step-down from root
		'su-exec>=0.2' \
# add tzdata for https://github.com/docker-library/redis/issues/138
		tzdata

ENV REDIS_VERSION 5.0.3
ENV REDIS_DOWNLOAD_URL http://download.redis.io/releases/redis-5.0.3.tar.gz
ENV REDIS_DOWNLOAD_SHA e290b4ddf817b26254a74d5d564095b11f9cd20d8f165459efa53eb63cd93e02

# for redis-sentinel see: http://redis.io/topics/sentinel
RUN set -ex; \
	\
	apk add --no-cache --virtual .build-deps \
		coreutils \
		gcc \
		jemalloc-dev \
		linux-headers \
		make \
		musl-dev \
	; \
	\
	wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL"; \
	echo "$REDIS_DOWNLOAD_SHA *redis.tar.gz" | sha256sum -c -; \
	mkdir -p /usr/src/redis; \
	tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1; \
	rm redis.tar.gz; \
	\
# disable Redis protected mode [1] as it is unnecessary in context of Docker
# (ports are not automatically exposed when running inside Docker, but rather explicitly by specifying -p / -P)
# [1]: https://github.com/antirez/redis/commit/edd4d555df57dc84265fdfb4ef59a4678832f6da
	grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 1$' /usr/src/redis/src/server.h; \
	sed -ri 's!^(#define CONFIG_DEFAULT_PROTECTED_MODE) 1$!\1 0!' /usr/src/redis/src/server.h; \
	grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 0$' /usr/src/redis/src/server.h; \
# for future reference, we modify this directly in the source instead of just supplying a default configuration flag because apparently "if you specify any argument to redis-server, [it assumes] you are going to specify everything"
# see also https://github.com/docker-library/redis/issues/4#issuecomment-50780840
# (more exactly, this makes sure the default behavior of "save on SIGTERM" stays functional by default)
	\
	make -C /usr/src/redis -j "$(nproc)"; \
	make -C /usr/src/redis install; \
	\
	rm -r /usr/src/redis; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --virtual .redis-rundeps $runDeps; \
	apk del .build-deps; \
	\
	redis-server --version

RUN mkdir /data && chown redis:redis /data
VOLUME /data
WORKDIR /data

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 6379


#3 update apk, install dependencies
RUN apk update \
&& apk upgrade \
&& apk add --no-cache \
build-base \
clang \
clang-dev \
cmake \
git \
pkgconf \
wget \
libtbb@edge-testing \
libtbb-dev@edge-testing \
libjpeg \
libjpeg-turbo-dev \
libpng \
libpng-dev \
tiff \
tiff-dev \
libjasper \
jasper-dev \
python \
python-dev \
py-numpy@edge-community \
py-numpy-dev@edge-community \
linux-headers

#4 Build opencv
RUN cd /tmp \
&& wget -O opencv-$OPENCV_VERSION.tar.gz https://github.com/opencv/opencv/archive/$OPENCV_VERSION.tar.gz \
&& tar -xzf opencv-$OPENCV_VERSION.tar.gz \
&& cd /tmp/opencv-$OPENCV_VERSION \
&& mkdir build \
&& mkdir /usr/local/opencv \
&& cd build \
&& CC=/usr/bin/clang CXX=/usr/bin/clang++ cmake \
-D CMAKE_BUILD_TYPE=RELEASE \
-D CMAKE_INSTALL_PREFIX=/usr/local/opencv \
-D WITH_FFMPEG=NO \
-D WITH_IPP=NO \
-D WITH_OPENEXR=NO \
-D WITH_TBB=YES \
-D WITH_1394=NO \
-D BUILD_PERF_TESTS=OFF \
-D BUILD_TESTS=OFF .. \
&& make -j2 \
&& make install \
&& cd /

#5 Clean
RUN rm -rf /tmp/opencv-$OPENCV_VERSION*  \
&& apk del \
build-base \
clang \
clang-dev \
cmake \
git \
pkgconf \
wget \
libtbb-dev \
libjpeg-turbo-dev \
libpng-dev \
tiff-dev \
jasper-dev \
python-dev \
py-numpy-dev
 
