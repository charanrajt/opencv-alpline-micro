FROM alpine:3.5
LABEL maintainer "charanrajt@gmail.com"
ENV OPENCV_VERSION 4.0



#2 Add Edge and bleeding repos
# add the edge repositories
RUN echo "@edge-testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
echo "@edge-community http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

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
linux-headers
#ibjasper \
#jasper-dev \
#python \
#python-dev \
#py-numpy@edge-community \
#py-numpy-dev@edge-community \

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
-D BUILD_SHARED_LIBS=OFF\
-D BUILD_TESTS=OFF .. \
&& make -j2 \
&& make install 

#5 Clean
RUN rm -rf /tmp/opencv-$OPENCV_VERSION*  \
&& apk del \
build-base \
clang-dev \
git \
pkgconf \
wget \
libtbb-dev \
libjpeg-turbo-dev \
libpng-dev \
tiff-dev \
jasper-dev 
#python-dev \
#py-numpy-dev\
#cmake \
#clang \

 
