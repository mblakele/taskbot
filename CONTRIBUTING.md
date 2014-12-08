# Contributing to taskbot

Yes, please: taskbot welcomes new contributors.
This document will guide you through the process.

 - [Question or Problem?](#question)
 - [Issues and Bugs](#issue)
 - [Feature Requests](#feature)
 - [Submission Guidelines](#submit)
 
## <a name="question"></a> Got a Question or Problem?

If you have questions about how to use taskbot, you may open a question ticket 
on GitHub.

## <a name="issue"></a> Found an Issue?

If you find a bug in the source code, you can help us by submitting an issue 
to our [GitHub Issue Tracker][issue tracker]. Even better you can submit a 
Pull Request with a fix for the issue you filed.

## <a name="feature"></a> Want a Feature?

You can request a new feature by submitting an issue to our 
[GitHub Issue Tracker][issue tracker]. If you would like to implement a new 
feature then first create a new issue and discuss it with one of the project 
maintainers.

## <a name="submit"></a> Submission Guidelines

### Submitting an Issue

If your issue appears to be a bug, and hasn't been reported, open a new issue.
Help us to maximize the effort we can spend fixing issues and adding new
features by not reporting duplicate issues. Providing the following information 
will increase the chances of your issue being dealt with quickly:

* **Overview of the Issue** - if an error is being thrown a stack trace helps
* **Motivation for or Use Case** - explain why this is a bug for you
* **Environment** - What's the environment where you saw the problem? Windows/Mac/Linux? What's the full MarkLogic version number?
* **Suggest a Fix** - if you can't fix the bug yourself, perhaps you can point 
to what might be causing the problem (line of code or commit)

### Submitting a Pull Request

#### Fork taskbot

Fork the project [on GitHub](https://github.com/mblakele/taskbot/fork) and 
clone your copy.

```sh
$ git clone git@github.com:username/taskbot.git
$ cd taskbot
$ git remote add upstream git://github.com/mblakele/taskbot.git
```

We ask that you open an issue in the [issue tracker][] and get agreement from
at least one of the project maintainers before you start coding.

Nothing is more frustrating than seeing your hard work go to waste because
your vision does not align with that of a project maintainer.

#### Create a branch for your changes

Okay, so you have decided to fix something. Create a feature branch
and start hacking:

```
sh
$ git checkout -b my-feature-branch -t origin/dev
```

#### Formatting code

Try to match the formatting of the existing code.
Wherever possible keep lines well under 80 characters.

#### Commit your changes

Make sure git knows your name and email address:

```
sh
$ git config --global user.name "John Doe"
$ git config --global user.email "john.doe@example.com"
```

Writing good commit logs is important. A commit log should describe what 
changed and why. Follow these guidelines when writing one:

1. The first line should be 50 characters or less and contain a short
   description of the change including the Issue number prefixed by a hash (#).
2. Keep the second line blank.
3. Wrap all other lines at 72 columns.

A good commit log looks like this:

```
Fixing Issue #123: make the whatchamajigger work in MarkLogic 8

Body of commit message is a few lines of text, explaining things
in more detail, possibly giving some background about the issue
being fixed, etc etc.

The body of the commit message can be several paragraphs, and
please do proper word-wrap and keep columns shorter than about
72 characters or so. That way `git log` will show things
nicely even when it is indented.
```

The header line should be meaningful; it is what other people see when they
run `git shortlog` or `git log --oneline`.

#### Rebase your repo

Use `git rebase` (not `git merge`) to sync your work from time to time.

```sh
$ git fetch upstream
$ git rebase upstream/dev
```

Ideally a pull request contains just one commit.
You can still develop in stages with multiple commits,
then use `git rebase -i` to coalesce them.
Be careful! Only rebase your own commits, never those from upstream.

#### Test your code

We use [xray](http://www.xqueryhacker.com/xray/) for unit testing.
You can run the existing tests by visiting `/xray?dir=test`
on your local app server with any web browser.
You can also run xray tests from the command line.
Assuming you have taskbot set up on port 8268:

    $ ./xray/test-runner.sh \
	  -u http://localhost:8268/xray/ \
	  -d test \
      -c username:password

The existing test cases are stored in XQuery library modules
under `test`. You can edit those files to modify existing tests,
add new tests to a library module, or add a new library module.

#### Push your changes

```
sh
$ git push origin my-feature-branch
```

After you've pushed your changes it's best to keep the remote copy of
your feature branch unchanged. You can still develop locally,
but you might want to create another branch to avoid any confusion.

#### Submit the pull request

Go to https://github.com/username/taskbot and select your feature branch. Click
the 'Pull Request' button and fill out the form.

Pull requests are usually reviewed within a few days. If you get comments
that need to be to addressed, you may need to create a new  pull request.
apply your changes in a separate commit and push 
that to your feature branch. Post a comment in the pull request afterwards; 
GitHub does not send out notifications when you add commits to existing pull 
requests.

That's it! Thank you for your contribution!


#### After your pull request is merged

After your pull request is merged, you can safely delete your branch
and pull the changes from the main (upstream) repository:

* Delete the remote branch on GitHub either through the GitHub web UI or your local shell as follows:

    ```
    shell
    git push origin --delete my-feature-branch
    ```

* Check out the master branch:

    ```
    shell
    git checkout master -f
    ```

* Delete the local branch:

    ```
    shell
    git branch -D my-feature-branch
    ```

* Update your master with the latest upstream version:

    ```
    shell
    git pull --ff upstream master
    ```

[issue tracker]: https://github.com/mblakele/taskbot/issues
[.editorconfig]: http://editorconfig.org/
