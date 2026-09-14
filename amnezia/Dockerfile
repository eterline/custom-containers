FROM registry.eterline.ru/amnezia-base:latest
COPY ./entrypoint.sh /entrypoint.sh
RUN apk update && apk add bash && chmod +x /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
