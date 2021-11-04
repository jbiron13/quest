# A quest in the clouds

### Implementation

A couple different implementations were done as part of this project.

#### CloudFormation
A template to create an EC2 instance was created. This template creates the instance and necessary infratstucture and deploys the straight code. This results in an instance that serves the page without most of the requirements. The rest of the requirments are met in the k8s implementation.

#### Terraform

##### This implementation contains all the requirements. It includes:
  - A Dockerfile to create the iamge.
  - Terraform templates to create an EKS cluster and all the resources needed.
  - Helm templates to deploy the application into the cluster.
  
#### Endpoints:
  - http://a8e9d08ce45744257a668900012019b0-615723343.us-east-1.elb.amazonaws.com/. This shows everything except SSL.
  - https://quest.nhmaker.com. This endpoint uses Route 53 to create the DNS entry. The page reports that traffic did not go over a load balancer however the IP addresses for both the nhmaker.com address and the direct elb address are the same. I do not know why the application does not recognize this.

#### Notes:
While most of the setup was done via Terraform and Helm, a couple of steps were accomplished manually due to time constraints:
  - The Route 53, certificate creation, and SSL listener were configured manually.
  - The secret word was added manually.
  - No CI/CD pipeline was created. Creating/pushing the docker image, building the tar file, and invoking the various tools was performed from the command-line.

This was fun. I tried many different things to improve this deployment but, again due to time constraints, I went with relatively simple solutions. Given additional time, or should this be a production implementation, I would also implement:
  - Auto-scaling
  - Secrets stored in Secrets Manager instead of as a k8s secret
  - IaC for any configuration peformed manually

Thanks for looking. Let me know if you have any questions or comments.

JB

### Q. What is this quest?

It is a fun way to assess your cloud skills. It is also a good representative sample of the work we do at Rearc. Quest is a webapp made with node.js and golang.

### Q. Do I need to be an expert in node.js and golang?

No. The starting point of the quest app is `npm install && npm start`. That is all the node.js you need to know. And you wont even see golang.

### Q. So what skills should I have?

AWS. General cloud concepts, especially networking. Docker (containerization). IaC (Infrastructure as code). Linux/Unix. Git. TLS certs is a plus.

### Q. What do I have to do?

You may do all or some of the following tasks. Please read over the complete list before starting.

1. If you know how to use git, start a git repository (local-only is acceptable) and commit all of your work to it.
2. Deploy the app in AWS and navigate to the index page. Use Linux 64-bit as your OS (Amazon Linux preferred).
3. Deploy the app in a Docker container. Use `node:10` as the base image.
4. Inject an environment variable (`SECRET_WORD`) in the Docker container. The value of `SECRET_WORD` should be the secret word discovered on the index page of the application.
5. Deploy a load balancer in front of the app.
6. Use Infrastructure as Code (IaC) to "codify" your deployment. Terraform is ideal, but use whatever you know, e.g. CloudFormation, CDK, Deployment Manager, etc.
7. Add TLS (https). You may use locally-generated certs.

### Q. How do I know I have solved these stages?

Each stage can be tested as follows (where `<ip_or_host>` is the location where the app is deployed):

1. Index page (contains the secret word) - `http(s)://<ip_or_host>[:port]/`
2. Docker check - `http(s)://<ip_or_host>[:port]/docker`
3. Secret Word check - `http(s)://<ip_or_host>[:port]/secret_word`
4. Load Balancer check  - `http(s)://<ip_or_host>[:port]/loadbalanced`
5. TLS check - `http(s)://<ip_or_host>[:port]/tls`

### Q. Do I have to do all these?

You may do whichever, and however many, of the tasks above as you'd like. We suspect that once you start, you won't be able to stop. It's addictive.

### Q. What do I have to submit?

1. Your work assets, as one or both of the following:
  - A link to a hosted git repository.
  - A ZIP file containing your project directory. Include the `.git` sub-directory if you used git.
2. Proof of completion, as one or both of the following:
  - A link to a hosted AWS deployment.
  - One or more screenshots showing, at least, the index page of the final deployment.

Your work assets should include:

- IaC files, if you completed that task.
- One or more Dockerfiles, if you completed that task.
- A sensible README or other file(s) that contain instructions, notes, or other written documentation to help us review and assess your submission.

### Q. How long do I need to host my submission on AWS?

You don't have to at all if you don't want to. You can run it in AWS, grab a screenshot, then tear it all down to avoid costs.

If you _want_ to host it longer for us to view it, we recommend taking a screenshot anyway and sending that along with the link. Then you can tear down the quest whenever you want and we'll still have the screenshot. We recommend waiting no longer than one week after sending us the link before tearing it down.

### Q. What if I successfully complete all the challenges?

We have many more for you to solve as a member of the Rearc team!

### Q. What if I find a bug?

Awesome! Tell us you found a bug in your submission to us, ideally in an email, and we'll talk more!

### Q. What if I fail?

There is no fail. Complete whatever you can and then submit your work. Doing _everything_ in the quest is not a guarantee that you will "pass" the quest, just like not doing something is not a guarantee you will "fail" the quest.

### Q. Can I share this quest with others?

No.
