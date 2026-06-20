FROM node:20-slim

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm install

COPY . .

EXPOSE 5173

# Run Vite dev server, bound to 0.0.0.0
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
