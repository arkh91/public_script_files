#!/bin/bash

# Function to validate email
validate_email() {
  local email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
  if [[ $1 =~ $email_regex ]]; then
    return 0
  else
    return 1
  fi
}

# Get the domain name
read -p "Enter your domain name (e.g., example.com): " domain

# Get the email with validation
while true; do
  read -p "Enter your email address: " email
  if validate_email "$email"; then
    break
  else
    echo "Invalid email format. Please try again."
  fi
done

# Confirm the details
echo "Domain: $domain"
echo "Email: $email"
read -p "Are these details correct? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
  echo "Exiting setup."
  exit 1
fi

# Install certbot if it's not installed
if ! command -v certbot &> /dev/null; then
  echo "Certbot not found. Installing certbot..."
  sudo apt update
  sudo apt install -y certbot
fi

# Request SSL certificate
echo "Requesting SSL certificate for $domain..."
sudo certbot --apache -d "$domain" --email "$email" --agree-tos --non-interactive --redirect

# Confirm completion
if [[ $? -eq 0 ]]; then
  echo "SSL certificate setup completed successfully for $domain."
else
  echo "There was an error setting up the SSL certificate."
fi
