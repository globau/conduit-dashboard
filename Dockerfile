FROM alpine:3.14

RUN apk update \
    && apk upgrade
RUN apk add --no-cache curl make wget perl perl-dev openssl openssl-dev zlib-dev build-base

RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app
RUN mkdir -p /app

RUN curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -rf ./cpanm /root/.cpanm
ENV PERL_CPANM_OPT --mirror https://cpan.metacpan.org --mirror-only --notest

COPY cpanfile /app
RUN cpanm --installdeps /app

RUN apk del make build-base
RUN rm -rf /root/.cpanm /usr/local/share/man

COPY ./ /app
RUN chown -R app:app /app

STOPSIGNAL SIGINT
EXPOSE 8000
USER app
WORKDIR /app
CMD [ "./dashboard.app", "daemon", "--listen", "http://0.0.0.0:8000/", "-m", "production" ]
