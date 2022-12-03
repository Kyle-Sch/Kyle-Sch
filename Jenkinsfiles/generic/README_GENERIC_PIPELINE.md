# Generic Jenkins File

## Creating and configuring a Multibranch Pipeline
1. Create a new Jenkins Item
2. Name the pipeline and select the "Multibranch Pipeline" option
3. Configure the pipeline with the following settings...

### Branch Sources
    - Click "add source"
    Project Repository: link to the project's gitlab repository
    Credentials: FXS_APP1085_SRC

### Build Configuration
    Mode: Custom Script
    Marker File: path of the pom.xml in the project's repository
 
    #### Pipeline
        Defintion: Pipeline Script from SCM
        SCM: Git
        Repository URL: git@gitlab.prod.fedex.com:APP1085/universal-pipelines.git
        Credentials: FXS_APP1085_SRC
        Scipt path: "generic_pipeline"


### Properties

    ARTIFACT_ID - comes from the pom file
    GROUP_ID - comes from the pom file
    PROJECT_ROOT_FOLDER - the root folder of the project. If    there is none, set it equal to nothing
    PROJECT_NAME - This is what the project will be named in SonarQube. This is typically a camel-cased version of the artifact_id
    PACKAGING - jar or tar depending on the project
    SOURCE_URL - link to the gitlab repository
    DEPLOYMENT_URL - link to the gitlab deployment repository 
    BUILD_WITH_FAILING_UNIT_TESTS - true or false depending on the project's desired behavior
    BRANCHES_EXCLUDED_FROM_APPENDS - branch names that we don’t want to have anything appended to the version numbers during snapshot builds (develop|master|etc)


## Example Multibranch Pipeline
https://jenkins-fxg.prod.cloud.fedex.com:8443/jenkins/job/HubAndOutbound/job/ISS-1085/job/ISS-Publisher_Multibranch_Matt/