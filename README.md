# What is it?
Shush is a tool to help you manage your shell scripts. It builds a cli tool dynamically based off of the folder structure of a specified directory.
So when you run "shush" in your terminal, where managed-repos is you configured shush to look for scripts at, and it sees the below directory structure

!!! ADD GIF OF RUNNING THE TOOL !!!

# Installation
Install with the below command
```bash
# !!! INSERT COMMAND HERE !!!
```
Then make sure that "$HOME/.local/bin" is in to your "$PATH" so that the shush script can be referenced from any location
```bash
# You can run the below command to see what your current path is
echo $PATH

# If it's not your path, then edit your "$HOME/.zshrc" or "$HOME/.bashrc" and add the below text to the bottom
export PATH=$HOME/.local/bin:$PATH
```

Now run the shush in your terminal
```bash
shush
```

Now it will prompt you for where you want to store your sh files. For me I created a folder at "$HOME/managed-repos"

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
