FROM akorn/luarocks:lua5.1-alpine as build

RUN apk add \
    gcc \
    git \
    libc-dev \
    make

# copy the local repo contents and build it
COPY ./ /tmp/homie-millheat
WORKDIR /tmp/homie-millheat
RUN luarocks make

# collect cli scripts; the ones that contain "LUAROCKS_SYSCONFDIR" are Lua ones
RUN mkdir /luarocksbin \
 && grep -rl LUAROCKS_SYSCONFDIR /usr/local/bin | \
    while IFS= read -r filename; do \
      cp "$filename" /luarocksbin/; \
    done



FROM akorn/lua:5.1-alpine

ENV HOMIE_LOG_LOGLEVEL "debug"

# copy luarocks tree and data over
COPY --from=build /luarocksbin/* /usr/local/bin/
COPY --from=build /usr/local/lib/lua /usr/local/lib/lua
COPY --from=build /usr/local/share/lua /usr/local/share/lua
COPY --from=build /usr/local/lib/luarocks /usr/local/lib/luarocks

CMD ["homie-zipato"]
