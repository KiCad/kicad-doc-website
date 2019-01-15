FROM kicadeda/kicad-doc-builder-base:latest as doc-build-env

WORKDIR /src
RUN git clone https://github.com/KiCad/kicad-doc.git .

RUN mkdir -p build/4.0.7
RUN git checkout --force tags/4.0.7
WORKDIR /src/build/4.0.7
RUN cmake -DBUILD_FORMATS="pdf;epub" ../../
RUN make

RUN mkdir -p build/5.0.2
RUN git checkout --force tags/5.0.2
WORKDIR /src/build/5.0.2
RUN cmake -DBUILD_FORMATS="pdf;epub" ../../
RUN make

################################

FROM ruby:2.5 as site-build-env

WORKDIR /site

# install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

#copy the entire website folder into the build environment container
COPY . .

COPY --from=doc-build-env /src/build/4.0.7/src /site/kicad-doc-built/4.0.7
COPY --from=doc-build-env /src/build/5.0.2/src /site/kicad-doc/built/5.0.2

#actually build the site
RUN rake process 

RUN jekyll build

######################################

# lets create the actual deployment image
FROM nginx:alpine

#copy over the site config for nginx
COPY ./.docker/default.conf /etc/nginx/conf.d/default.conf

#copy over the built website from the build environment docker
COPY --from=site-build-env /site/_site /usr/share/nginx/html

# change permissions to allow running as arbitrary user
RUN chmod -R 777 /var/log/nginx /var/cache/nginx /var/run \
     && chgrp -R 0 /etc/nginx \
     && chmod -R g+rwX /etc/nginx

# use a different user as open shift wants non-root containers
# do it at the end here as it'll block our "root" commands to set the container up
USER 1000

#expose 8081 as we cant use port 80 on openshift (non-root restriction)
EXPOSE 8081