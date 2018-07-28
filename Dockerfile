FROM node:8-alpine
LABEL maintainer Yuki Takei <yuki@weseek.co.jp>

ADD https://github.com/progrium/entrykit/releases/download/v0.4.0/entrykit_0.4.0_Linux_x86_64.tgz /entrykit.tgz
ADD https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh /bin/wait-for-it

ENV APP_VERSION v3.1.14
ENV APP_DIR /opt/growi

# update tar for '--strip-components' option
RUN apk add --no-cache --update tar
# download GROWI archive from Github
RUN apk add --no-cache --virtual .dl-deps curl \
    && mkdir -p ${APP_DIR} \
    && curl -SL https://github.com/weseek/growi/archive/${APP_VERSION}.tar.gz \
        | tar -xz -C ${APP_DIR} --strip-components 1 \
    && apk del .dl-deps

WORKDIR ${APP_DIR}

# setup
RUN apk add --no-cache --virtual .build-deps git \
    && yarn \
    # install official plugins
    && yarn add growi-plugin-lsx growi-plugin-pukiwiki-like-linker \
    && npm run build:prod \
    # shrink dependencies for production
    && yarn install --production \
    && yarn cache clean \
    && apk del .build-deps

RUN apk add --no-cache mongodb bash

RUN tar xf /entrykit.tgz \
    && rm /entrykit.tgz \
    && mv ./entrykit /bin/entrykit \
    && chmod +x /bin/entrykit \
    && /bin/entrykit --symlink \
    && chmod +x /bin/wait-for-it

COPY docker-entrypoint.sh /
COPY run_mongo.sh /
RUN chmod +x /docker-entrypoint.sh
RUN chmod +x /run_mongo.sh

VOLUME /data
VOLUME /data/db
EXPOSE 3000

ENV MONGO_URI=mongodb://localhost:27017/growi

ENTRYPOINT ["codep", \
                "wait-for-it localhost:27017 -t 0 -- /docker-entrypoint.sh npm run server:prod", \
                "/run_mongo.sh mongod --bind_ip 0.0.0.0" ]
