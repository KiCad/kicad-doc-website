################################

FROM ruby:2.5 as site-build-env

WORKDIR /site

# install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

#copy the entire website folder into the build environment container
COPY . .

COPY --from=index.docker.io/kicadeda/kicad-doc:4.0.7 /src /site/kicad-doc-built/4.0.7
COPY --from=index.docker.io/kicadeda/kicad-doc:5.0.2 /src /site/kicad-doc-built/5.0.2
COPY --from=index.docker.io/kicadeda/kicad-doc:5.1.5 /src /site/kicad-doc-built/5.1.5
COPY --from=index.docker.io/kicadeda/kicad-doc:master /src /site/kicad-doc-built/master

#actually build the site
RUN rake process

RUN jekyll build

######################################

# lets create the actual deployment image
FROM nginx:alpine

#copy over the site config for nginx
COPY ./.docker/default.conf /etc/nginx/conf.d/default.conf
COPY ./.docker/kicad-downloads-proxy-pass.conf /etc/nginx/conf.d/kicad-downloads-proxy-pass.conf

#copy over the built website from the build environment docker
COPY --from=site-build-env /site/_site /usr/share/nginx/html

#copy the doxygen docs
COPY --from=index.docker.io/kicadeda/kicad-doc-doxygen:master /doxygen-docs_html /usr/share/nginx/html/doxygen
COPY --from=index.docker.io/kicadeda/kicad-doc-doxygen:master /doxygen-python_html /usr/share/nginx/html/doxygen-python

# change permissions to allow running as arbitrary user
RUN chmod -R 777 /var/log/nginx /var/cache/nginx /var/run \
     && chgrp -R 0 /etc/nginx \
     && chmod -R g+rwX /etc/nginx

# use a different user as open shift wants non-root containers
# do it at the end here as it'll block our "root" commands to set the container up
USER 1000

#expose 8081 as we cant use port 80 on openshift (non-root restriction)
EXPOSE 8081
