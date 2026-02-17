FROM openjdk:21-slim

WORKDIR /minecraft

# サーバーファイルをコピー
COPY server.jar /minecraft/server.jar
COPY server.properties /minecraft/server.properties
COPY eula.txt /minecraft/eula.txt
COPY mods /minecraft/mods
COPY world /minecraft/world

# ポート公開
EXPOSE 25565

# サーバー起動
CMD ["java", "-Xmx1800m", "-Xms1800m", "-jar", "server.jar", "nogui"]
