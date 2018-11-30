FROM alpine
RUN apk add --no-cache curl jq socat make

# ENV FOO Foo

COPY . /oksh
WORKDIR /oksh
# CMD ["make", "test"]
