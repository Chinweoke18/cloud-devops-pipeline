# Copy package.json and package-lock.json if available
COPY package*.json ./

# Install the dependencies
RUN npm install

# Copy all source files into the container
COPY . .

# Install 'serve' globally for serving React files
RUN npm install -g serve

# Expose port 5000 (default port for `serve`)
EXPOSE 5000

# Use `serve` to serve the React application
CMD ["serve", "-s", "./src/main/js"]