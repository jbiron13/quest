FROM node:10
ADD quest.tar /quest
EXPOSE 3000
WORKDIR /quest
ENTRYPOINT [ "npm","start" ]