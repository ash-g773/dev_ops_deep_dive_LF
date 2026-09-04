### 15:15–16:45 — Capstone: Load-Balanced VMs & a Remote Backend
*(Activity: 90 min)*

Two connected pieces. **Part A** scales your single VM into a load-balanced fleet of three, one per availability zone. **Part B** moves state off your laptop into Azure Blob Storage.

Work individually or in pairs. **Get Part A running and verified before starting Part B.**

Watch the clock and the cost here. Part A is the more satisfying half — seeing traffic alternate between three servers is genuinely memorable — but **Part B is the more important one**. <br>

Make sure by 16:00 if you haven't started **Part B** to cut Part A's stretch work and complete Part B. 


---

#### Part A1 (≈15 min) — Set up the project and multiply the network resources

*(Run from `~/terraform-training/05-virtual-machines`)*
```bash
cd ..
```

*(Run from `~/terraform-training`)*
```bash
mkdir 06-vms-with-lb
cd 05-virtual-machines
```

*(Run from `~/terraform-training/05-virtual-machines`)*
```bash
cp data-providers.tf main.tf network-security-group.tf variables.tf ../06-vms-with-lb/
cd ../06-vms-with-lb
```

Rename the VM resource to a plural, because it'll represent many:

**06-vms-with-lb/main.tf**
```tf
# UPDATED — plural name to reflect many resources
resource "azurerm_linux_virtual_machine" "http_servers" {
  [ . . . ]
}
```

Each VM needs **its own NIC** and **its own public IP**, so those iterate too — over the subnets map we already have:

**main.tf**
```tf
# UPDATED CONFIG
resource "azurerm_public_ip" "http_server_pips" {
  for_each            = azurerm_subnet.public_subnets
  name                = "pip-http-server-${each.key}"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "http_server_nics" {
  for_each            = azurerm_subnet.public_subnets
  name                = "nic-http-server-${each.key}"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.http_server_pips[each.key].id
  }
}

resource "azurerm_network_interface_security_group_association" "http_server_nics_nsg" {
  for_each                  = azurerm_network_interface.http_server_nics
  network_interface_id      = each.value.id
  network_security_group_id = azurerm_network_security_group.http_server_nsg.id
}
```

**This is the pattern that makes `for_each` powerful**, so slow down here.

**`for_each = azurerm_subnet.public_subnets`** — we're iterating over **another resource** that was itself created with `for_each`. Because that resource is a map keyed by `"1"`, `"2"`, `"3"`, iterating it gives us the same keys:
- `each.key` is `"1"`, `"2"`, `"3"` — used in names
- `each.value` is the whole **subnet object**, so `each.value.id` is that subnet's ID

**`azurerm_public_ip.http_server_pips[each.key].id`** — reach into the *matching* public IP by key. Because every collection shares the same keys, everything lines up: **NIC `"2"` gets public IP `"2"` in subnet `"2"`.**

**ASK YOURSELF** <br>
Why is keying everything consistently like this so much safer than three sets of numbered resources? <br>
**ANSWER** <br>
Because **the key is the identity**. Remove subnet `"2"` from the map and Terraform removes exactly that subnet, its NIC, its public IP and its VM — leaving `"1"` and `"3"` untouched. With positional indexes everything after the removal would shift and get rebuilt. It's Part 1's list-versus-set lesson.

Add an output:

*(Run from `~/terraform-training/06-vms-with-lb`)*
```bash
touch outputs.tf
```

**outputs.tf**
```tf
# NEW CONFIG
output "http_server_public_ips" {
  value = { for k, pip in azurerm_public_ip.http_server_pips : k => pip.ip_address }
}
```

That's a **`for` expression** — HCL's comprehension syntax. Read it as: "for each key `k` and value `pip` in the collection, produce an entry mapping `k` to `pip.ip_address`". The `{ }` means we're building a map; `[ ]` would build a list.

Suppose we had a JS object:

```js
const collection = {
  server1: { ip: "10.0.0.1" },
  server2: { ip: "10.0.0.2" }
};
```

Our HCL for loop could look like:

```tf
{ for k, v in collection : k => v.ip }
# For the key, value in collection, create a dictionary (map) where the key is the key and the value is v.ip
```

Producing a result like:

```js
{
  server1 = "10.0.0.1"
  server2 = "10.0.0.2"
}
```

---

#### Part A2 (≈15 min) — Three VMs

**main.tf**
```tf
resource "azurerm_linux_virtual_machine" "http_servers" {
  # NEW CONFIG
  for_each              = azurerm_subnet.public_subnets
  name                  = "http-server-${each.key}"
  resource_group_name   = azurerm_resource_group.vm_resource_group.name
  location              = azurerm_resource_group.vm_resource_group.location
  size                  = "Standard_B2als_v2"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.http_server_nics[each.key].id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.azure_ssh_public_key)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = data.azurerm_platform_image.ubuntu_latest.version
  }

  tags = {
    name = "http-server-${each.key}"
  }

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.http_server_pips[each.key].ip_address
    user        = "azureuser"
    private_key = file(var.azure_ssh_private_key)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install apache2 -y",
      "sudo systemctl start apache2",
      "echo Welcome - Virtual Server ${each.key} is at ${azurerm_public_ip.http_server_pips[each.key].ip_address} | sudo tee /var/www/html/index.html"
    ]
  }
}
```

Note the provisioner message now includes `${each.key}` — **each server identifies itself.** That's how we'll prove the load balancer is actually distributing traffic.

*(Run from `~/terraform-training/06-vms-with-lb`)*
```bash
terraform init
terraform apply
# type: yes
```

Three HTTP servers. There's a lot of output — three VMs, each being SSH'd into and configured. Terraform does this **in parallel** where the graph allows, which is why the output interleaves.


Watch the cost. A single "Standard_B2als_v2" has a managable cost, but **three at once burns that allowance three times as fast**, and the Standard-SKU public IPs and load balancer are **chargeable from the first minute**. Keep runtime short and make sure you destroy resources after using.

---

#### Part A3 (≈20 min) — The Load Balancer

A load balancer needs **its own NSG** — we don't want SSH open on the public entry point to our whole application.

**network-security-group.tf**
```tf
# HTTP_SERVER NSG ABOVE
[ . . . ]

# NEW CONFIG — LOAD BALANCER
resource "azurerm_network_security_group" "lb_nsg" {
  name                = "lb-nsg"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name
}

resource "azurerm_network_security_rule" "lb_http_ingress" {
  name                        = "AllowHTTP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "0.0.0.0/0"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vm_resource_group.name
  network_security_group_name = azurerm_network_security_group.lb_nsg.name
}
```

**ASK YOURSELF** <br>
Why does the load balancer's NSG have an HTTP rule but **no SSH rule**? <br>
**ANSWER** <br>
**Least privilege.** The load balancer's job is to accept web traffic and pass it on — nobody should ever SSH into it. Every port you open is attack surface, so you open only what's needed. Same principle as scoping a Service Principal to one resource group rather than a whole subscription, and the same principle as `Contributor` rather than `Owner`.

**Unlike AWS's all-in-one Classic Load Balancer, Azure spreads this across several linked resources**: a frontend Public IP, the Load Balancer, a Backend Address Pool, a Health Probe, and a Load Balancing Rule.

The options, before we build:

| Option | For |
|---|---|
| **Basic SKU** | The oldest tier, being retired |
| **Standard SKU** | Zone-redundant, higher scale, secure by default. **What we'll use** |
| **Application Gateway** | HTTP(S) content-based routing, path-based rules, WebSockets |
| **Azure Front Door** | Global routing and caching, worldwide content delivery |

**main.tf**
```tf
[ . . . ]

# NEW CONFIG
resource "azurerm_public_ip" "lb_pip" {
  name                = "pip-lb"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "lb"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name
  sku                 = "Standard"

  # The public-facing side, tied to our public IP
  frontend_ip_configuration {
    name                 = "lb-frontend"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb_backend_pool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "http-servers-pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "http_server_nics_pool" {
  for_each                = azurerm_network_interface.http_server_nics
  network_interface_id    = each.value.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend_pool.id
}

resource "azurerm_lb_probe" "http_probe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "http-probe"
  port            = 80
  protocol        = "Http"
  request_path    = "/"
}

resource "azurerm_lb_rule" "http_rule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "http-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "lb-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend_pool.id]
  probe_id                       = azurerm_lb_probe.http_probe.id
}
```

Reading the pieces:

**`frontend_ip_configuration`** — the **front door**, the single address users hit. Note its `name` (`"lb-frontend"`); the rule refers back to it by that name.

**`azurerm_lb_backend_address_pool`** — where traffic goes. It starts **empty**.

**`azurerm_network_interface_backend_address_pool_association`** — another **join resource**, iterated, adding each NIC to the pool. `ip_configuration_name = "internal"` matches the name we gave inside the NIC — a NIC can have several IP configurations, so we say which one joins.

**`azurerm_lb_probe`** — the health check.

**ASK YOURSELF** <br>
Why does a load balancer need a health probe — why not just send traffic to all three servers? <br>
**ANSWER** <br>
Because a server can be **running** while being **broken** — Apache crashed, disk full, app wedged. The probe repeatedly requests `/`; if a server stops responding correctly it's **taken out of rotation automatically**, and put back when it recovers. Without it, the load balancer cheerfully sends a third of your users to a dead machine. **This is what turns three servers into genuine resilience rather than just three servers.**

**`azurerm_lb_rule`** — read it as a sentence: *traffic arriving on frontend port 80, at the frontend named `lb-frontend`, goes to backend port 80 on members of this pool, provided the probe says they're healthy.*

Note `frontend_port` and `backend_port` are separate — they don't have to match. A common real pattern is **443 in, 80 out**, terminating TLS at the load balancer.

**outputs.tf**
```tf
output "http_server_public_ips" {
  value = { for k, pip in azurerm_public_ip.http_server_pips : k => pip.ip_address }
}

# NEW CONFIG
output "lb_public_ip" {
  value = azurerm_public_ip.lb_pip.ip_address
}
```

*(Run from `~/terraform-training/06-vms-with-lb`)*
```bash
terraform apply
# type: yes
```

*(In your browser)* — visit the `lb_public_ip` value.



Don't panic if the first request fails — the load balancer and its health probe take **a few minutes** to settle, and until the probe confirms a server is healthy it won't route to it. <br>
Also remeber to make your request as `HTTP` requests, not `HTTPS`


Keep refreshing. You'll see it alternate between servers 1, 2 and 3 — the message you wrote with `${each.key}` telling you which one you hit.

Then have a look at the graph:

*(Run from `~/terraform-training/06-vms-with-lb`)*
```bash
terraform graph
```

Paste into Graphviz Online — considerably more interesting than this morning's.

**Destroy before moving on** — this is the expensive part of the day:

*(Run from `~/terraform-training/06-vms-with-lb`)*
```bash
terraform destroy
# type: yes
```


**Solution — Part A**

*Please note the solution uses `jbloggs` as afunctional creater in resource group and virtual network names, etc.*

The complete `main.tf`:

```tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "vm_resource_group" {
  name     = "rg-vm-jbloggs-devops"
  location = "swedencentral"
}

resource "azurerm_virtual_network" "vm_vnet" {
  name                = "vnet-jbloggs-devops"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name
}

resource "azurerm_subnet" "public_subnets" {
  for_each             = { "1" = "10.0.1.0/24", "2" = "10.0.2.0/24", "3" = "10.0.3.0/24" }
  name                 = "subnet-public-${each.key}"
  resource_group_name  = azurerm_resource_group.vm_resource_group.name
  virtual_network_name = azurerm_virtual_network.vm_vnet.name
  address_prefixes     = [each.value]
}

# --- One public IP and NIC per subnet ---

resource "azurerm_public_ip" "http_server_pips" {
  for_each            = azurerm_subnet.public_subnets
  name                = "pip-http-server-${each.key}"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "http_server_nics" {
  for_each            = azurerm_subnet.public_subnets
  name                = "nic-http-server-${each.key}"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.http_server_pips[each.key].id
  }
}

resource "azurerm_network_interface_security_group_association" "http_server_nics_nsg" {
  for_each                  = azurerm_network_interface.http_server_nics
  network_interface_id      = each.value.id
  network_security_group_id = azurerm_network_security_group.http_server_nsg.id
}

# --- Three VMs, one per subnet ---

resource "azurerm_linux_virtual_machine" "http_servers" {
  for_each              = azurerm_subnet.public_subnets
  name                  = "http-server-${each.key}"
  resource_group_name   = azurerm_resource_group.vm_resource_group.name
  location              = azurerm_resource_group.vm_resource_group.location
  size                  = "Standard_B2als_v2"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.http_server_nics[each.key].id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.azure_ssh_public_key)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = data.azurerm_platform_image.ubuntu_latest.version
  }

  tags = {
    name = "http-server-${each.key}"
  }

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.http_server_pips[each.key].ip_address
    user        = "azureuser"
    private_key = file(var.azure_ssh_private_key)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install apache2 -y",
      "sudo systemctl start apache2",
      "echo Welcome - Virtual Server ${each.key} is at ${azurerm_public_ip.http_server_pips[each.key].ip_address} | sudo tee /var/www/html/index.html"
    ]
  }
}

# --- Load balancer ---

resource "azurerm_public_ip" "lb_pip" {
  name                = "pip-lb"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "lb"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "lb-frontend"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb_backend_pool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "http-servers-pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "http_server_nics_pool" {
  for_each                = azurerm_network_interface.http_server_nics
  network_interface_id    = each.value.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend_pool.id
}

resource "azurerm_lb_probe" "http_probe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "http-probe"
  port            = 80
  protocol        = "Http"
  request_path    = "/"
}

resource "azurerm_lb_rule" "http_rule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "http-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "lb-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend_pool.id]
  probe_id                       = azurerm_lb_probe.http_probe.id
}
```

---

#### Part B1 (≈10 min) — Set up the backend-state project

*(Run from `~/terraform-training`)*
```bash
mkdir -p 07-backend-state/users
mkdir -p 07-backend-state/backend-state
cd 07-backend-state/users
```

*(Run from `~/terraform-training/07-backend-state/users`)*
```bash
touch main.tf outputs.tf
```

Keep the `users` project deliberately simple:

**07-backend-state/users/main.tf**
```tf
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azuread" {}

# REMEMBER: YOUR tenant domain, not mine
resource "azuread_user" "my_azuread_user" {
  user_principal_name = "my_iam_user_def@jbloggs.onmicrosoft.com"
  display_name        = "my_iam_user_def"
  mail_nickname       = "my_iam_user_def"
  password            = "ChangeMe123!ChangeMe"
}
```

**07-backend-state/users/outputs.tf**
```tf
output "my_azuread_user_complete_details" {
  value = azuread_user.my_azuread_user
}
```

*(Run from `~/terraform-training/07-backend-state/users`)*
```bash
terraform init
terraform apply
# type: yes
ls -la          # note terraform.tfstate is HERE, locally
```

**ASK YOURSELF** <br>
Why two separate sub-projects rather than one? <br>
**ANSWER** <br>
**Chicken and egg.** You can't store a project's state in a storage account that the same project is responsible for creating — the first `apply` would need the backend to exist before it had created it. So `backend-state` creates the storage; `users` consumes it. And in practice one backend storage account serves **many** projects: users, VMs, load balancers, all of them.

---

#### Part B2 (≈15 min) — Build the storage account

*(Run from `~/terraform-training/07-backend-state/backend-state`)*
```bash
touch main.tf
```

**backend-state/main.tf**
```tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "backend_resource_group" {
  name     = "rg-backend-state-jbloggs-devops"
  location = "uksouth"
}

resource "azurerm_storage_account" "organisation_backend_state" {
  name                     = "stdevappsbackendjbloggs"
  resource_group_name      = azurerm_resource_group.backend_resource_group.name
  location                 = azurerm_resource_group.backend_resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "tfstate_container" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.organisation_backend_state.name
  container_access_type = "private"
}
```

**On naming the storage account** — you have a choice of scope:

- **One account for everything** — all state, all projects, all environments
- **One per environment** — `stdevbackend`, `stprodbackend`
- **One per application per environment** — `stapplicationnamebackend`

Remember: no hyphens or underscores, globally unique. We're using `stdevappsbackend<yourname>`.

Three things this gives us:
- **`versioning_enabled = true`** — every state write keeps the previous version, so a corrupted state can be rolled back
- **Encryption at rest** — on by default. No extra resource, unlike AWS
- **`container_access_type = "private"`** — no anonymous access. **Absolutely not optional** for a file containing secrets

*(Run from `~/terraform-training/07-backend-state/backend-state`)*
```bash
terraform init
terraform validate
terraform apply
# type: yes
```

---

#### Part B3 (≈15 min) — Migrate the users project

Point `users` at that storage. Add a **`backend`** block **inside** the `terraform { }` block:

**07-backend-state/users/main.tf**
```tf
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }

  # NEW CONFIG
  backend "azurerm" {
    resource_group_name  = "rg-backend-state-jbloggs-devops"
    storage_account_name = "stdevappsbackendjbloggs"
    container_name       = "tfstate"
    key                  = "07-backend-dev-users.tfstate"
  }
}
```

- `backend "azurerm"` — the backend *type*. Others include `s3`, `gcs`, `remote`
- `resource_group_name` / `storage_account_name` / `container_name` — where the storage lives
- `key` — the **blob name** the state is stored under. **This is what separates one project's state from another's** in the same container


Values in a `backend` block **cannot be interpolated** — no `var.` references, no expressions. It exists because the backend must be resolved **before** Terraform has evaluated any variables.

*(Run from `~/terraform-training/07-backend-state/users`)*
```bash
terraform init
```


Terraform detects the backend change and asks whether to **copy the existing local state** to the new backend.

- Type: `yes`

If it errors, use `terraform init -reconfigure`.

Now delete the local copies — they're no longer authoritative:

*(Run from `~/terraform-training/07-backend-state/users`)*
```bash
rm terraform.tfstate terraform.tfstate.backup
ls -la
```

*(In the Azure Portal — **Storage accounts → stdevappsbackend... → Containers → tfstate**)*

There's a blob named exactly what you set as `key`. Open it — it's your Known State.

*(Run from `~/terraform-training/07-backend-state/users`)*
```bash
terraform plan
```

**It works with no local state file at all** — Terraform fetched it from Azure.

#### A better key structure

A flat filename works, but a **hierarchical** key using forward slashes gives Azure pseudo-folders and scales far better.

First destroy, because we're changing where state lives — otherwise you'd get a fresh empty state trying to create a user that already exists:

*(Run from `~/terraform-training/07-backend-state/users`)*
```bash
terraform destroy
# type: yes
```

**users/main.tf**
```tf
  backend "azurerm" {
    resource_group_name  = "rg-backend-state-jbloggs-devops"
    storage_account_name = "stdevappsbackendjbloggs"
    container_name       = "tfstate"
    # key = environment / application / project / state
    # NEW CONFIG
    key = "dev/07-backend-state/users/backend-state.tfstate"
  }
```

*(Run from `~/terraform-training/07-backend-state/users`)*
```bash
terraform init -reconfigure
terraform apply
# type: yes
```

*(In the Azure Portal — the `tfstate` container)* — refresh until you see the `dev/` prefix.


Azure's tooling **displays** slash-separated prefixes as a folder hierarchy, so it's browsable. More importantly it gives a **consistent, predictable convention** — any engineer can work out where a given project's state lives — and you can grant **RBAC access by prefix**, letting a team read `dev/` state but not `prod/`. The structure carries meaning even though the storage is flat.


**Solution — Part B**

**backend-state/main.tf** — as written above.

**users/main.tf**
```tf
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-backend-state-jbloggs-devops"
    storage_account_name = "stdevappsbackendjbloggs"
    container_name       = "tfstate"
    key                  = "dev/07-backend-state/users/backend-state.tfstate"
  }
}

provider "azuread" {}

resource "azuread_user" "my_azuread_user" {
  user_principal_name = "my_iam_user_def@jbloggs.onmicrosoft.com"
  display_name        = "my_iam_user_def"
  mail_nickname       = "my_iam_user_def"
  password            = "ChangeMe123!ChangeMe"
}
```

The full sequence:

*(Run from `~/terraform-training/07-backend-state/backend-state`)*
```bash
terraform init
terraform apply         # type: yes — creates RG, storage account, container
```

*(Run from `~/terraform-training/07-backend-state/users`)*
```bash
terraform init          # type: yes to copy state to the backend
rm terraform.tfstate terraform.tfstate.backup
terraform plan          # works with no local state
terraform destroy       # type: yes, BEFORE changing the key
# ...update key to the hierarchical form...
terraform init -reconfigure
terraform apply         # type: yes
```

**Stretch:**
- Open two terminals in the `users` folder. Start `terraform apply` in one and, while it's waiting for confirmation, run `terraform plan` in the other. **Watch the second one report the state is locked**, and see whose lock it is
- Turn on blob versioning in the Portal and look at the version history of your state blob after a few applies
