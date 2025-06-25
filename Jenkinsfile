pipeline {
    /*
     * Jenkins Pipeline for deploying an EKS cluster using Terraform
     * This pipeline includes stages for initialization, validation, planning, security scanning,
     * manual approval, and deployment.
     */
   /* agent {
        label 'terraform-aws'
    } */
    agent any   
   
    environment {
        AWS_REGION             = 'us-west-3'
        TF_VERSION            = '1.5.0'
        TF_IN_AUTOMATION      = 'true'
        TF_INPUT              = 'false'
        KUBE_VERSION          = '1.28'
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '5'))
    }

    stages {
        stage('Checkout & Setup') {
            steps {
                checkout scm
                sh 'terraform --version'
                sh 'aws --version'
                sh 'kubectl version --client'
            }
        }

        stage('Terraform Init') {
            steps {
                sh 'rm -rf .terraform .terraform.lock.hcl'
               sh 'terraform init -upgrade'
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'AWS_CREDENTIALS',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                    terraform plan \
                        -var="aws_region=${AWS_REGION}" \
                        -var="cluster_version=${KUBE_VERSION}" \
                        -out=tfplan \
                        -no-color
                    '''
                }
            }
        }

        stage('Security Scan') {
            steps {
                sh 'terraform show -no-color tfplan > tfplan.txt'
                sh 'checkov -f tfplan.txt --skip-check CKV_AWS_58,CKV_AWS_88 --soft-fail'
            }
        }

        stage('Manual Approval') {
            when {
                branch 'main'
            }
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    input message: 'Approve Terraform Apply?', ok: 'Deploy'
                }
            }
        }

        stage('Terraform Apply') {
            when {
                anyOf {
                    branch 'main'
                    triggeredBy 'TimerTrigger'
                }
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'AWS_CREDENTIALS',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh 'terraform apply -auto-approve -no-color tfplan'
                }
            }
        }
    }
    post {
        always {
           // archiveArtifacts artifacts: '**/tfplan*', allowEmptyArchive: true
          //  junit '**/terraform-test-report.xml'
            sh 'echo  In the post build'
        }
        success {
           // slackSend color: 'good', message: "EKS Deployment Successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
            sh 'echo  SUCESS'
        }
        failure {
           // slackSend color: 'danger', message: "EKS Deployment Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
             sh 'echo  FAIL'
        }
    }
}
