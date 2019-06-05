def label = "worker-${UUID.randomUUID().toString()}"

podTemplate(label: label, containers: [
  containerTemplate(name: 'maven', image: 'maven:3.3.9-jdk-8-alpine', command: 'cat', ttyEnabled: true),
  containerTemplate(name: 'docker', image: 'docker', command: 'cat', ttyEnabled: true),
  containerTemplate(name: 'kubectl', image: 'docker.io/lachlanevenson/k8s-kubectl', command: 'cat', ttyEnabled: true),
],
volumes: [
  hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock'),
  persistentVolumeClaim(claimName: 'jenkins-pvc', mountPath: '/home/jenkins')  
])


{
  node(label) {
     def myRepo, gitCommit, gitBranch, shortGitCommit, previousGitCommit
     stage('Checkout') 
     {
        try {
           myRepo = checkout scm
           gitCommit = myRepo.GIT_COMMIT
           gitBranch = myRepo.GIT_BRANCH
           shortGitCommit = "${gitCommit[0..10]}"
           previousGitCommit = sh(script: "git rev-parse ${gitCommit}~", returnStdout: true)
        }
        catch(Exception e) {
           println "ERROR => Code Checkout failed, exiting..."
           throw e
        }
     }
     stage('Build') {
      try {
        container('maven') {
            sh """
              mvn clean install -Dmaven.test.skip=true
            """
        }
      }
      catch (Exception e) {
        println "Failed to Maven Build - ${currentBuild.fullDisplayName}"
        throw e
      }
    }
    stage('Unit Test') {
      try {
        container('maven') {
            sh """
              mvn test -Dmaven.test.skip=false
            """
        }
      }
      catch (Exception e) {
        println "Failed to test - ${currentBuild.fullDisplayName}"
        throw e
      }
    }
    stage('Sonar Analysis') {
      try {
        container('maven') {
            withSonarQubeEnv('SonarQubeServer') {
              sh "mvn -DBranch=${gitBranch} -Dsonar.branch=${gitBranch} -e -B sonar:sonar"
            }
        }
      }
      catch (Exception e) {
        println "Failed to Sonar - ${currentBuild.fullDisplayName}"
        throw e
      }
    }
    stage('Quality Gate') {
      try {
        container('maven') {
          withSonarQubeEnv('SonarQubeServer') {
          timeout(time: 1, unit: 'HOURS') {
              def qg = waitForQualityGate()
              if (qg.status != 'OK' && qg.status != 'WARN') {
                error "Pipeline aborted due to quality gate failure: ${qg.status}"
              }
          }
          }
        }
      }
      catch (Exception e) {
        println "Failed to Sonar QG - ${currentBuild.fullDisplayName}"
        throw e
      }
    }
    stage('Upload Artifact') {
      try {
        container('maven') {
	  sh "cp target/myweb-0.0.5.war myweb-0.0.5-${BUILD_NUMBER}.war"
          nexusArtifactUploader(
			      nexusVersion: 'nexus3',
			      protocol: 'http',
			      nexusUrl: '34.83.196.108:8081',
			      groupId: 'in.javahome',
		              version: "0.0.5-${BUILD_NUMBER}",
			      repository: 'kube-pipeline-demo',
			      credentialsId: 'nexes-admin',
			      artifacts: [
			      [artifactId: 'myweb',
			      classifier: '',
			        file: "myweb-0.0.5-${BUILD_NUMBER}.war",
			        type: 'war']
			      ]
			    )
        }
      }
      catch (Exception e) {
        println "Failed to Upload Artifact - ${currentBuild.fullDisplayName}"
        throw e
      }
    }
  stage('Build Docker Image') {
      try {
        container('docker') {
            withCredentials([[$class: 'UsernamePasswordMultiBinding',
          credentialsId: 'dockerhub',
          usernameVariable: 'DOCKER_HUB_USER',
          passwordVariable: 'DOCKER_HUB_PASSWORD']]) {
          sh """
            docker login -u ${DOCKER_HUB_USER} -p ${DOCKER_HUB_PASSWORD}
            docker build -t sureshchandrarhca15/mytomcat:${gitCommit} --build-arg VERSION="0.0.5-${BUILD_NUMBER}" .
            docker push sureshchandrarhca15/mytomcat:${gitCommit}
	    """
        }
	}
      }
      catch (Exception e) {
        println "Failed to Build Docker Image - ${currentBuild.fullDisplayName}"
        throw e
      }
    }
	  
stage('Deploy on Kubernetes') {
      try {
        container('kubectl') {
            withKubeConfig(caCertificate: '', clusterName: 'standard-cluster-1', contextName: '', credentialsId: 'kube-admin', namespace: 'default', serverUrl: 'https://35.247.106.248') {
		    sh "kubectl set image deployment/tomcat tomcat-container=sureshchandrarhca15/mytomcat:${gitCommit}"
        }
	}
      }
      catch (Exception e) {
        println "Failed to deploy on Kubernetes - ${currentBuild.fullDisplayName}"
        throw e
      }
    }
 
	 
  }
}
