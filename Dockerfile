FROM rust:1.35-slim

ENV CARGO_BUILD_TARGET_DIR=/tmp/target \
    LC_CTYPE=ja_JP.utf8 \
    LANG=ja_JP.utf8 \
    RUBY_MAJOR=2.5 \
    RUBY_VERSION=2.5.5 \
    RUBY_DOWNLOAD_SHA256=9bf6370aaa82c284f193264cc7ca56f202171c32367deceb3599a4f354175d7d \
    RUBYGEMS_VERSION=3.0.3 \
    BUNDLER_VERSION=2.0.1

# install ruby
RUN apt-get update -y -q \
  && apt-get install -y -q \
    locales \
    gcc \
    make \
    autoconf \
    openssl \
    zlib1g-dev \
    libssl-dev \
    libreadline-dev \
    g++ \
    curl \
    wget \
    git \
  && echo "ja_JP UTF-8" > /etc/locale.gen \
  && locale-gen \
  # skip installing gem documentation
  && mkdir -p /usr/local/etc \
  && { \
    echo 'install: --no-document'; \
    echo 'update: --no-document'; \
  } >> /usr/local/etc/gemrc \
  # some of ruby's build scripts are written in ruby
  #   we purge system ruby later to make sure our final image uses what we just built
  && set -ex \
  \
  && buildDeps=' \
    bison \
    dpkg-dev \
    libgdbm-dev \
    ruby \
  ' \
  && apt-get update \
  && apt-get install -y --no-install-recommends $buildDeps \
  && rm -rf /var/lib/apt/lists/* \
  \
  && wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%}/ruby-$RUBY_VERSION.tar.xz" \
  && echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum -c - \
  \
  && mkdir -p /usr/src/ruby \
  && tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1 \
  && rm ruby.tar.xz \
  \
  && cd /usr/src/ruby \
  \
  # hack in "ENABLE_PATH_CHECK" disabling to suppress:
  #   warning: Insecure world writable dir
  && { \
    echo '#define ENABLE_PATH_CHECK 0'; \
    echo; \
    cat file.c; \
  } > file.c.new \
  && mv file.c.new file.c \
  \
  && autoconf \
  && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
  && ./configure \
    --build="$gnuArch" \
    --disable-install-doc \
    --enable-shared \
  && make -j "$(nproc)" \
  && make install \
  \
  && apt-get purge -y --auto-remove $buildDeps \
  && cd / \
  && rm -r /usr/src/ruby \
  \
  && gem update --system "$RUBYGEMS_VERSION" \
  && gem install bundler --version "$BUNDLER_VERSION" --force

CMD ["bash"]
