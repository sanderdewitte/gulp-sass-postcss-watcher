FROM ubuntu:xenial

# update image and install tools
RUN set -ex \
 && apt-get -qq update \
 && apt-get -qq upgrade \
 && essentialTools='apt-utils wget git' \
 && buildTools='build-essential autoconf' \
 && apt-get -qq install -y --no-install-recommends $essentialTools $buildTools

# set versions
ENV RUBY_MAJOR=2.4 \
    RUBY_VERSION=2.4.2 \
    RUBYGEMS_VERSION=2.6.13 \
    BUNDLER_VERSION=1.15.4 \
    NODE_VERSION=6.11.4

# set gem versions
ENV GEM_SASS_VERSION="~> 3.5" \
    GEM_BOURBON_VERSION="~> 5.0.0.beta" \
    GEM_NEAT_VERSION="~> 2.1" \
    GEM_BITTERS_VERSION="~> 1.7"

# set gem home and working directory 
ENV GEM_HOME=/usr/local/bundle \
    WORK_DIR=/data/src

# set bundler variables and prepend bundle binaries to path
ENV BUNDLE_PATH="$GEM_HOME" \
    BUNDLE_BIN="$GEM_HOME/bin" \
    BUNDLE_APP_CONFIG="$GEM_HOME" \
    BUNDLE_SILENCE_ROOT_WARNING=1 \
    PATH=$BUNDLE_BIN:$PATH

# set log level for node.js package manager
ENV NPM_CONFIG_LOGLEVEL=error

# download, compile and install ruby
RUN mkdir -p /usr/local/etc \
 && { echo 'install: --no-document'; echo 'update: --no-document'; } >> /usr/local/etc/gemrc
RUN set -ex \
 && buildDeps='bison libgdbm-dev libssl-dev libreadline-dev zlib1g-dev ruby' \
 && apt-get -qq install -y --no-install-recommends $buildDeps \
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
 && apt-get -qq purge -y --auto-remove $buildDeps \
 && cd / \
 && rm -r /usr/src/ruby \
 && gem update --system "$RUBYGEMS_VERSION"

# install bundler and gems
RUN gem install bundler --version "$BUNDLER_VERSION" \
 && mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
 && chmod 777 "$GEM_HOME" "$BUNDLE_BIN"
RUN gemSource="https://rubygems.org" \
 && rubyVersion=$RUBY_VERSION \
 && gemSassVersion=$GEM_SASS_VERSION \
 && gemBourbonVersion=$GEM_BOURBON_VERSION \
 && gemNeatVersion=$GEM_NEAT_VERSION \
 && gemBitterVersion=$GEM_BITTER_VERSION \
 && { echo "source \"$gemSource\""; \
      echo "ruby \"$rubyVersion\""; \
      echo "gem \"sass\", \"$gemSassVersion\""; \
      echo "gem \"bourbon\", \"$gemBourbonVersion\""; \
      echo "gem \"neat\", \"$gemNeatVersion\""; \
      echo "gem \"bitters\", \"$gemBitterVersion\""; } > /var/tmp/Gemfile \
 && cd /var/tmp && bundle install
 
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
RUN wget -O node.tar.gz "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz" \
 && tar -xzf "node.tar.gz" -C /usr/local --strip-components=1 \
 && rm "node.tar.gz"

# install postcss, the gulp toolkit, the node-sass library and the smaller version of the caniuse-db
RUN npm install --global postcss \
 && npm install --global gulp-cli \
 && npm install --global gulp \
 && npm install --global gulp-postcss \
 && npm install --global gulp-sass \
 && npm install --global node-sass \
 && npm install --global caniuse-lite

# install postcss plugins via package.json file
ADD package.json /var/tmp/package.json
RUN cd /var/tmp \
 && npm install

# create externally mounted directory and set it as working directory
VOLUME ["$WORK_DIR"]
WORKDIR $WORK_DIR

# start executable
ENTRYPOINT ["sass"]
