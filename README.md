# What is it?
Shush is a tool to help you manage your shell scripts. It builds a cli tool dynamically based off of the folder structure of a specified directory.

https://github.com/user-attachments/assets/dfc90725-5596-47f6-8e13-05f67abc0b09

# Installation
Make sure you have nodejs version 20.0.0 or above ([Download here](https://nodejs.org/en/download))
```bash
node -v
```

Then install with the below command
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/CoryMConway/shush/refs/heads/main/install_shush.sh)
```
<img width="1588" height="574" alt="image" src="https://github.com/user-attachments/assets/1425edd8-e3d2-4a83-b37b-e77cedc797bb" />


Now open a new terminal and run the "shush" command
```bash
shush
```

# Update shush to latest code
All you have to do is run this update command!
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/CoryMConway/shush/refs/heads/main/update_shush.sh)
```
<img width="1917" height="1034" alt="image" src="https://github.com/user-attachments/assets/da99f7ae-820a-462a-a05c-fdb48fe08440" />

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

<img width="1918" height="1045" alt="image" src="https://github.com/user-attachments/assets/4841bafb-897e-4a02-82ce-fe39020a4d60" />
# Bash Scripts
Bash scripts work right out of the box and require no special changes. If you can run it in your terminal, you can run it from shush.

# Python Scripts
For python, you might need certain dependencies. So you MUST include a shebang to the interpreter that you want your script to run against.

## Virtualenv
TODO

# Next steps
- support python scripts
- support node.js scripts
