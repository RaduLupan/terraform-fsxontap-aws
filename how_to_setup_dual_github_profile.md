# Setting Up Dual GitHub Profiles on Windows

This guide provides step-by-step instructions for setting up and managing two separate GitHub profiles (work and personal) on a Windows machine using SSH.

## Prerequisites

- Ensure that you have [Git](https://git-scm.com/downloads) installed on your machine.
- Ensure that you have access to your work and personal GitHub accounts.

## Step 1: Generate SSH Keys

First, generate separate SSH keys for each GitHub account.

### Generate SSH Key for Work

Open PowerShell and run the following command:

```
ssh-keygen -t rsa -b 4096 -C "your_work_email@example.com" -f $env:USERPROFILE\.ssh\id_rsa_work
```

### Generate SSH Key for Personal

Similarly, generate an SSH key for your personal account:

```
ssh-keygen -t rsa -b 4096 -C "your_personal_email@example.com" -f $env:USERPROFILE\.ssh\id_rsa_personal
```

## Step 2: Add SSH Keys to SSH Agent

Start the SSH agent and add your keys:

```
Start-Service ssh-agent
ssh-add $env:USERPROFILE\.ssh\id_rsa_work
ssh-add $env:USERPROFILE\.ssh\id_rsa_personal
```

## Step 3: Upload SSH Public Keys to GitHub

### For Work Account

1. Log into your work GitHub account.
2. Navigate to **Settings** > **SSH and GPG keys** > **New SSH key**.
3. Copy the contents of `id_rsa_work.pub` and paste it into GitHub.

### For Personal Account

1. Log into your personal GitHub account.
2. Navigate to **Settings** > **SSH and GPG keys** > **New SSH key**.
3. Copy the contents of `id_rsa_personal.pub` and paste it into GitHub.

## Step 4: Configure SSH for Multiple Accounts

Edit your SSH config file:

```
notepad $env:USERPROFILE\.ssh\config
```

Add the following configurations:

```
# Work account
Host github-work
    HostName github.com
    User git
    IdentityFile C:\Users\YourUsername\.ssh\id_rsa_work

# Personal account
Host github-personal
    HostName github.com
    User git
    IdentityFile C:\Users\YourUsername\.ssh\id_rsa_personal
```

## Step 5: Configure Git Repositories

- **For Work Repository:**

  Set the remote URL to use the work host:

  ```
  git remote set-url origin git@github-work:your_work_username/repo.git
  ```

- **For Personal Repository:**

  Set the remote URL to use the personal host:

  ```
  git remote set-url origin git@github-personal:your_personal_username/repo.git
  ```

## Step 6: Set Git User Configurations

- **For Global Configuration (Personal by default):**

  ```
  git config --global user.name "Your Personal Name"
  git config --global user.email "your_personal_email@example.com"
  ```

- **For Work Repository Configuration:**

  Navigate to your work repository and set locally:

  ```
  git config user.name "Your Work Name"
  git config user.email "your_work_email@example.com"
  ```

## Conclusion

Your Windows environment is now set up to handle dual GitHub profiles using SSH keys. Use the corresponding configurations whenever you are working with repositories for each of your GitHub accounts.