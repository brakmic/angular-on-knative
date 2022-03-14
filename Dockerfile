#build
FROM node:17.7.1-alpine3.14 as node
WORKDIR /app
COPY . .
RUN npm install
RUN npm run build --prod
#run
FROM nginx:stable-alpine
COPY --from=node /app/dist/ng-demo /usr/share/nginx/html
EXPOSE 80
