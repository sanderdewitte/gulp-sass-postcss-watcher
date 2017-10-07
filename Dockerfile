FROM ubuntu:xenial

# update image and install tools
RUN set -ex \
  && apt-get update -qq \
  && apt-get upgrade -qq \
  && essentialTools='apt-utils wget git' \
  && buildTools='build-essential autoconf libssl-dev libreadline-dev zlib1g-dev' \
  && apt-get install -y --no-install-recommends $essentialTools $buildTools

# set versions
ENV RUBY_MAJOR 2.4
ENV RUBY_VERSION 2.4.2
ENV RUBYGEMS_VERSION 2.6.13
ENV BUNDLER_VERSION 1.15.4
ENV NODE_VERSION 6.11.4

# set bundler variables
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME"
ENV BUNDLE_BIN="$GEM_HOME/bin"
ENV BUNDLE_SILENCE_ROOT_WARNING=1
ENV BUNDLE_APP_CONFIG="$GEM_HOME"

# prepend bundle binaries to path
ENV PATH $BUNDLE_BIN:$PATH

# set log level for node.js package manager
ENV NPM_CONFIG_LOGLEVEL info

# download, compile and install ruby
RUN mkdir -p /usr/local/etc \
  && { echo 'install: --no-document'; echo 'update: --no-document'; } >> /usr/local/etc/gemrc
RUN set -ex \
  && buildDeps='bison libgdbm-dev ruby' \
  && apt-get install -y --no-install-recommends $buildDeps \
  && rm -rf /var/lib/apt/lists/* \
  && wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz" \
  && mkdir -p /usr/src/ruby \
  && tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1 \
  && rm ruby.tar.xz \
  && cd /usr/src/ruby \
  && { echo '#define ENABLE_PATH_CHECK 0'; echo; cat file.c; } > file.c.new \
  && mv file.c.new file.c \
  && autoconf \
  && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
  && ./configure --build="$gnuArch" --disable-install-doc --enable-shared \
  && make -j "$(nproc)" \
  && make install \
  && apt-get purge -y --auto-remove $buildDeps \
  && cd / \
  && rm -r /usr/src/ruby \
  && gem update --system "$RUBYGEMS_VERSION"

# install bundler and gems
RUN gem install bundler --version "$BUNDLER_VERSION" \
  && mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
  && chmod 777 "$GEM_HOME" "$BUNDLE_BIN"
RUN { echo "source https://rubygems.org"; echo "ruby $RUBY_VERSION"; echo "gem listen"; echo "gem sass"; echo "gem bourbon"; echo "gem neat"; echo "gem bitters"} > /usr/local/etc/Gemfile \
  && cd /usr/local/etc && bundle install && cd /

# download, compile and install libsass (C/C++ implementation of the sass compiler) and sassc (libsass command line driver)
RUN cd /usr/local/lib \
  && git clone https://github.com/sass/libsass.git --depth 1 \
  && git clone https://github.com/sass/sassc.git --depth 1 
RUN cd /usr/local/lib \
  && export SASS_LIBSASS_PATH="/usr/local/lib/libsass" \
  && make -C libsass \
  && make -C sassc \
  && make -C sassc install \
  && make clean \
  && apt-get purge -y --auto-remove $buildTools

# install node.js
RUN wget -O node.tar.gz "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz" \
  && tar -xzf "node.tar.gz" -C /usr/local --strip-components=1 \
  && rm "node.tar.gz"

# install gulp toolkit and node-sass library providing bindings for node.js to libsass
RUN npm install -g gulp \
  && npm install -g node-sass

VOLUME /src
WORKDIR /src
ENTRYPOINT [ "sass" ]
