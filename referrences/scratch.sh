# Create the fetch_and_run.sh script 
cat << 'EOF' > /path/to/fetch_and_run.sh 
#!/bin/bash 
RAW_GITHUB="https://raw.githubusercontent.com" 
REPO="user/repository" 
SCRIPT="firstBoot.sh" 

# Fetch and run the remote script 
bash <(curl -s "$RAW_GITHUB/$REPO/$SCRIPT") 

EOF

# Make the script executable 
chmod +x /path/to/fetch_and_run.sh