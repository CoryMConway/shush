# What is it?
Shush is a tool to help you manage your shell scripts. It builds a cli tool dynamically based off of the folder structure of a specified directory.

https://github.com/user-attachments/assets/dfc90725-5596-47f6-8e13-05f67abc0b09

# Installation
Install with the below command
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/CoryMConway/shush/refs/heads/main/install_shush.sh)
```
<img width="1705" height="532" alt="image" src="https://github.com/user-attachments/assets/5884dd38-6751-47bd-81e7-eef149062f3b" />

Now open a new terminal and run the "shush" command
```bash
shush
```

# Update shush to latest code
TODO

# How it works
If you have specificed "$HOME/managed-repos" as your storage folder for your bash scripts, and you have a directory tree like below
```bash
managed-repos
    ├── Environment-Cleanup
    │   └── clean_test_qa_users.sh
    └── Web-Scraping
        └── Scrape_Stocks.sh
```
It will create a cli like so when you run "shush" in your terminal
'''bash
shush
'''
!!! INSERT CLI SCREENSHOT !!!

Next steps
- support python scripts
- support node.js scripts
