FROM alpine:3.14

RUN apk update \
    && apk upgrade
RUN apk add --no-cache curl make wget perl perl-dev openssl openssl-dev zlib-dev build-base

RUN curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -rf ./cpanm /root/.cpanm
ENV PERL_CPANM_OPT --mirror https://cpan.metacpan.org --mirror-only --notest

RUN mkdir -p /app/cache
COPY cpanfile /app
RUN cpanm --notest --installdeps /app

RUN apk del make build-base
RUN rm -rf /root/.cpanm
RUN rm -rf /usr/local/share/man

COPY ./ /app
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app
RUN chown -R app:app /app

STOPSIGNAL SIGINT
EXPOSE 8000
USER app
WORKDIR /app
CMD [ "./dashboard.app", "daemon", "--listen", "http://0.0.0.0:8000/", "-m", "production" ]
