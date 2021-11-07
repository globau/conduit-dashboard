# builder

FROM alpine:3.14 AS builder

RUN apk update \
    && apk upgrade
RUN apk add curl make wget perl perl-dev openssl openssl-dev zlib-dev build-base

RUN curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -rf ./cpanm /root/.cpanm
ENV PERL_CPANM_OPT --mirror https://cpan.metacpan.org --mirror-only --notest

RUN mkdir /app
COPY cpanfile /app
RUN cpanm --verbose --installdeps --notest --no-man-pages /app

# deploy

FROM alpine:3.14 AS deploy

RUN apk update \
    && apk upgrade
RUN apk add perl

RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app

COPY --from=builder /usr/local/lib/perl5/site_perl /usr/local/lib/perl5/site_perl
COPY --from=builder /usr/local/share/perl5/site_perl /usr/local/share/perl5/site_perl
COPY --chown=app:app ./ /app

STOPSIGNAL SIGINT
EXPOSE 8000
USER app
WORKDIR /app
CMD [ "./dashboard.app", "daemon", "--listen", "http://0.0.0.0:8000/", "-m", "production" ]
