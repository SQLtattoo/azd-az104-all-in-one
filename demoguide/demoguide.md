[comment]: <> (please keep all comment items at the top of the markdown file)
[comment]: <> (please do not change the ***, as well as <div> placeholders for Note and Tip layout)
[comment]: <> (please keep the ### 1. and 2. titles as is for consistency across all demoguides)
[comment]: <> (section 1 provides a bullet list of resources + clarifying screenshots of the key resources details)
[comment]: <> (section 2 provides summarized step-by-step instructions on what to demo)


[comment]: <> (this is the section for the Note: item; please do not make any changes here)
***
### AZ-104 Demo all-in-one

<div style="background: lightgreen; 
            font-size: 14px; 
            color: black;
            padding: 5px; 
            border: 1px solid lightgray; 
            margin: 5px;">

**Note:** Below demo steps should be used **as a guideline** for doing your own demos. Please consider contributing to add additional demo steps.
</div>

[comment]: <> (this is the section for the Tip: item; consider adding a Tip, or remove the section between <div> and </div> if there is no tip)

***
### 1. What Resources are getting deployed

<img src="https://raw.githubusercontent.com/sqltattoo/azd-az104-all-in-one/refs/heads/main/demoguide/images/az104allinone-diagram.png" alt="Solution diagram" style="width:70%;">
<br></br>

### 2. What can I demo from this scenario after deployment

- Hub and spoke network topology
- Application Gateway (with WAF) and Load Balancer configurations
- Web App Service behind the App GW, is allowing access only through the load balancer, checkout the network restrictions on it
- The 2 VMs behind the Azure LB have custom page to show the host's name so that you can demo the distribution
- Private Link, Standard LB behind it, with a VM and an IIS. A Private Endpoint is deployed in another region not peered vnet and gets access to the IIS.
- Azure Bastion for secure VM access
- Key Vault and Customer-Managed Keys
- VPN Gateway to show around the settings
- Recovery Services Vault to show around the settings
- Custom RBAC roles and Policy definitions
- Public DNS Zone to show around the setting
- Private DNS Zone used to demonstrate communication across vnet peering by hostname i.e. ping, nslookup
- Storage Account to demo Service Endpoint configuration



[comment]: <> (this is the closing section of the demo steps. Please do not change anything here to keep the layout consistant with the other demoguides.)
<br></br>
***
<div style="background: lightgray; 
            font-size: 14px; 
            color: black;
            padding: 5px; 
            border: 1px solid lightgray; 
            margin: 5px;">

</div>
