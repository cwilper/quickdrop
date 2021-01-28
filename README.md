# Quickdrop

Easy file sharing from macOS, using your own S3 bucket.

How it works:

1) Put a file in your `~/Quickdrop` folder
2) Quickdrop automatically moves it to S3 and puts the URL in your clipboard
3) Paste the URL anywhere

## Installation

Download and run `release/install.sh` manually, or use the follow curl or wget command:

```
curl -o- https://raw.githubusercontent.com/cwilper/quickdrop/1.0.1/release/install.sh | bash
```

```
wget -qO- https://raw.githubusercontent.com/cwilper/quickdrop/1.0.1/release/install.sh | bash
```

This will install the software in `~/.quickdrop`, prompt you to install the dependencies,
and run the setup script.

Once setup completes, the background agent will be running and you can immediately start
putting files in your `~/Quickdrop` folder.

## S3 Bucket Configuration

When setting up your S3 bucket, you need to make sure:

* The bucket is set up to allow public ACLs
* Each user you're connecting as has `s3:ListBucket` permission on the bucket,
  as well as `s3:*Object` and `s3:*ObjectAcl` permissions on objects in the bucket.

This can be done by creating a policy like the following, and associating it with the user
or a group the user is in (replace YOUR-BUCKET below with your bucket name):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListObjectsInBucket",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::YOUR_BUCKET"
            ]
        },
        {
            "Sid": "ObjectActions",
            "Effect": "Allow",
            "Action": "s3:*Object",
            "Resource": [
                "arn:aws:s3:::YOUR_BUCKET/*"
            ]
        },
        {
            "Sid": "ObjectAclActions",
            "Effect": "Allow",
            "Action": "s3:*ObjectAcl",
            "Resource": [
                "arn:aws:s3:::YOUR_BUCKET/*"
            ]
        }
    ]
}
```

## Commandline Scripts

In addition to the background agent, you can use the following utility scripts, located
in `~/.quickdrop/bin`, which you may optionally include in your `PATH`.

### qdls

Lists files in your quickdrop S3 bucket

### qdrm

Removes a single file from your quickdrop S3 bucket, by id (the random string before /filename).

### qdsetup

The setup script. You should run this if you change configuration, so you can be sure
Quickdrop still works. It will also restart the background agent that watches the `~/Quickdrop` folder.

### qdup

Uploads a single file to your quickdrop bucket and prints the URL. Does *not* delete the local copy.

### qdwatch, qdstart, and qdstop

These are used to control the running of the background agent that watches the ~/Quickdrop folder, and
normally don't need to be run manually. As long as Quickdrop is installed, the agent will be running
in the background.

## Uninstallation

To completely remove Quickdrop, run the following:

```
~/.quickdrop/bin/qdstop
rm ~/Library/LaunchAgents/com.github.cwilper.quickdrop.plist
rm -rf ~/.quickdrop ~/Quickdrop
```
