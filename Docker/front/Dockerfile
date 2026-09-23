# Etapa 1: Build da aplicação
FROM node:20-alpine AS build

WORKDIR /app

# Copiar arquivos de configuração e dependências
COPY package*.json ./
RUN npm install

# Copiar o restante do código
COPY . .

# Gerar build de produção
RUN npm run build

# Etapa 2: Servir com Nginx
FROM nginx:alpine

# Remover configuração padrão do Nginx
RUN rm -rf /usr/share/nginx/html/*

# Copiar arquivos gerados pelo Vite
COPY --from=build /app/dist /usr/share/nginx/html

# Expor porta 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
