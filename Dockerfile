FROM ubuntu:xenial

# prevent installers from opening dialog boxes and set software versions, gem home & working directory
ENV DEBIAN_FRONTEND=noninteractive \
    RUBY_MAJOR=2.4 \
    RUBY_VERSION=2.4.2 \
    RUBYGEMS_VERSION=2.6.14 \
    BUNDLER_VERSION=1.15.4 \
    NODE_VERSION=6.11.4 \
    GEM_HOME=/usr/local/gems \
    WORK_DIR=/data/src

# update image and install tools
RUN set -ex \
 && apt-get -qq update \
 && apt-get -qq upgrade \
 && essentialTools='apt-utils wget git' \
 && buildTools='build-essential autoconf' \
 && apt-get -qq install -y --no-install-recommends $essentialTools $buildTools

# set bundler variables
ENV BUNDLE_PATH="$GEM_HOME" \
    BUNDLE_BIN="$GEM_HOME/bin" \
    BUNDLE_APP_CONFIG="$GEM_HOME" \
    BUNDLE_SILENCE_ROOT_WARNING=1

# set log level for node.js package manager and add bundle binaries to path
ENV NPM_CONFIG_LOGLEVEL=error \
    PATH=$BUNDLE_BIN:$PATH

# download, compile and install ruby
RUN mkdir -p /usr/local/etc \
 && { echo 'install: --no-document'; echo 'update: --no-document'; } >> /usr/local/etc/gemrc
RUN set -ex \
 && buildDeps='bison libgdbm-dev libssl-dev libreadline-dev zlib1g-dev ruby' \
 && apt-get -qq install -y --no-install-recommends $buildDeps \
 && rm -rf /var/lib/apt/lists/* \
 && wget -nv -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz" \
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
 && apt-get -qq purge -y --auto-remove $buildDeps \
 && cd / \
 && rm -r /usr/src/ruby \
 && gem update --system "$RUBYGEMS_VERSION"

# install bundler and gems
ADD Gemfile /var/tmp/Gemfile
RUN gem install bundler --version "$BUNDLER_VERSION" \
 && mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
 && chmod 777 "$GEM_HOME" "$BUNDLE_BIN" \
 && cd /var/tmp \
 && bundle install
 
# download, compile and install libsass (C/C++ implementation of the sass compiler) and sassc (libsass command line driver)
RUN cd /usr/local/lib \
 && git clone https://github.com/sass/libsass.git --depth 1 \
 && git clone https://github.com/sass/sassc.git --depth 1 
RUN cd /usr/local/lib \
 && export SASS_LIBSASS_PATH="/usr/local/lib/libsass" \
 && make -C libsass \
 && make -C libsass clean \
 && make -C sassc \
 && make -C sassc install \
 && make -C sassc clean \
 && apt-get -qq purge -y --auto-remove $buildTools

# install node.js
RUN wget -nv -O node.tar.gz "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz" \
 && tar -xzf "node.tar.gz" -C /usr/local --strip-components=1 \
 && rm "node.tar.gz"

RUN 
  
  

# install postcss, the node-sass library, the gulp toolkit, a package
# for parsing argument options and the smaller version of the caniuse-db
RUN cd $(npm root --global)/npm \
 && npm install --global fs-extra \
 && sed -i -e s/graceful-fs/fs-extra/ -e s/fs\.rename/fs.move/ ./lib/utils/rename.js \
 && npm install --global postcss \
 && npm install --global node-sass \
 && npm install --global gulp \
 && npm install --global gulp-cli \
 && npm install --global gulp-util \
 && npm install --global gulp-plumber \
 && npm install --global gulp-postcss \
 && npm install --global gulp-sass \
 && npm install --global minimist \
 && npm install --global caniuse-lite

# install postcss plugins via package.json file
ADD package.json /usr/local/lib/package.json
RUN cd /usr/local/lib \
 && npm install

# create externally mounted directory and set it as working directory
VOLUME ["$WORK_DIR"]
WORKDIR $WORK_DIR

# start executable
ENTRYPOINT ["gulp"]
