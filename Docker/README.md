Dockerfile notes
  - # is comments
  - \ line continuance
  - white space prior to anything gets ignored
  - dockerignore files

  - From
    - must begin with a FROM instruction
    - The FROM instruction specifies the Parent Image from which you are building. FROM may only be preceded by one or more ARG instructions, which declare arguments that are used in FROM lines in the Dockerfile
    - ARG (argument variable) is the only instruction that may precede FROM in the Dockerfile. 
    - can be used multiple times in a file

  -  Parser directives 
    - are written as a special type of comment in the form # directive=value
    - all parser directives must be at the very top of a Dockerfile.
    - Ex:# escape=\ (backslash)

  - ENV envionment variables
    - The ${variable_name} syntax also similar to standard bash
    - ${variable:-word} indicates that if variable is set then the result will be that value. If variable is not set then word will be the result.
    - Environment variables are supported by instruction key words ex: ADD, COPY, 

  - Run
    - The RUN instruction will execute any commands in a new layer on top of the current image and commit the results. The resulting committed image will be used for the next step in the Dockerfile.
        - ex: RUN /bin/bash -c 'source $HOME/.bashrc; echo $HOME'
    - RUN --mount allows you to create filesystem mounts that the build can access.