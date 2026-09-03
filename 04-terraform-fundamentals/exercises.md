### 15:15–16:45 — Capstone: Lists, Sets, `for_each` and Maps
*(Activity: 90 min)*

The main event. You're going to discover a genuine, well-known problem with `count`, fix it with `for_each`, then build up to configurations rich enough to describe real infrastructure.

Work individually or in pairs. **Work through Parts 1–4 in order** — each one motivates the next. Part 5 is stretch.

**NOTE FOR TRAINERS** <br>
Do not skip ahead to `for_each` because it's "the right answer". **The whole value of this capstone is that students hit the `count` problem themselves and feel it.** Part 2 asks them to predict what will happen, then shows them being wrong. That five seconds of surprise is worth more than any amount of explaining, and it's what makes the `for_each` rule stick permanently. <br>
**END OF NOTE**

---

#### Part 1 (≈20 min) — Driving resources from a list

Let's move away from `my_iam_user_0` and use real names.

*(Run from `~/terraform-training/02-count`)*
- Run: `terraform destroy` → type `yes`
- Run: `cd ..`

*(Run from `~/terraform-training`)*
- Run: `mkdir 03-lists-and-sets` → **cd inside**

*(Run from `~/terraform-training/03-lists-and-sets`)*
- Run: `touch main.tf`

**03-lists-and-sets/main.tf**
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

variable "names" {
  default = ["emile", "joseph", "mudathir", "guled"]
}

resource "azuread_user" "my_azuread_users" {
  count               = length(var.names)
  user_principal_name = "${var.names[count.index]}@jbloggs.onmicrosoft.com"
  display_name        = var.names[count.index]
  mail_nickname       = var.names[count.index]
  password            = "ChangeMe123!ChangeMe"
}
```

New syntax:

- `default = ["emile", "jospeh", "mudathir", "guled"]` — a **list**, square brackets. A JavaScript array, indexed from 0
- `length(var.names)` — a **built-in function**. In JavaScript you'd write `names.length`; HCL uses function-call syntax: `length(thing)`. It evaluates to 4, so `count.index` runs 0, 1, 2, 3
- `var.names[count.index]` — index into the list using the current iteration number

Notice `display_name = var.names[count.index]` has **no** `${ }` — the whole value *is* the expression. But `user_principal_name` needs it, because the value is embedded in a larger string alongside `@domain`.

*(Run from `~/terraform-training/03-lists-and-sets`)*
```bash
terraform init
terraform apply
```

- Type: `yes`



We keep making new project folders for a reason. It's **Terraform best practice** — a single application commonly has several separate Terraform projects, because different resources have different **lifecycles**.

A storage account might live for years, holding logs, assets and backups. A deployment might change daily. Grouping resources by how often they change, and managing each group as its own project with its own state, means a daily deployment change can never accidentally destroy the storage everything depends on. It also keeps `plan` fast and limits blast radius.




Explore in the console:

*(Run from `~/terraform-training/03-lists-and-sets`)*
```bash
terraform console
```

```
var.names
azuread_user.my_azuread_users[0].display_name
```

While you're here, meet the **collection functions**:

*Run in console*
```
length(var.names)                        # 4
reverse(var.names)                       # reverses the order
distinct(var.names)                      # removes duplicates
toset(var.names)                         # converts to a set
concat(var.names, ["manish", "monia"])   # joins two lists
contains(var.names, "simon")             # true / false
sort(var.names)                          # alphabetical
```

**ASK YOURSELF** <br>
Look at that list of functions. What do they remind you of? <br>

**JavaScript array methods** — `.length`, `.reverse()`, `.concat()`, `.includes()`, `.sort()`, and `new Set()`. Nearly one-for-one. The only real difference is **syntax**: HCL puts the collection *inside* the function call rather than calling a method on it. So `names.sort()` becomes `sort(var.names)`. If you know the array methods, you already know most of this.

Note `distinct` returns `tolist([...])` — Terraform being explicit that it produced a list.

And `range` for sequences:

*Run in console*
```
range(10)          # 0 to 9
range(1, 12)       # 1 up to but not including 12
range(1, 12, 3)    # third argument is the step: 1, 4, 7, 10
```

Exit with `Ctrl + C`. Get into the habit of checking the [function documentation](https://developer.hashicorp.com/terraform/language/functions) — there are dozens more.

---

#### Part 2 (≈20 min) — The problem with lists

**This section is the one of the main takeaways for today.** Add a name to the **front** of the list:

**main.tf**
```tf
variable "names" {
  # UPDATED
  default = ["bukayo", "emile", "joseph", "mudathir", "guled"]
}
```

**Before running anything — predict what will happen.** We added one name to a list of four.

*(Run from `~/terraform-training/03-lists-and-sets`)*
```bash
terraform apply
```

- *Read outout don't type 'yes'*

**1 to add… but 4 to change.**

**ASK YOURSELF** <br>
Why is Terraform changing four existing users? <br>
**ANSWER** <br>
Because `count` tracks resources by **position**, not identity. Everything shifted: `bukayo` now occupies index 0 where `emile` was, `emile` moved to 1, `joseph` to 2 — so Terraform sees each slot as having *changed value*, and index 4 (Guled's position) as brand new. It has no concept that "emile" is the same person who was there before; it only knows "the resource at index 0 used to be emile and should now be joe".

- *Cancel the `terraform apply`*

Look in the state file to see exactly why:

**terraform.tfstate**
```tf
"instances": [
  {
    "index_key": 0,                    # <-- A NUMBER
    "attributes": { "display_name": "emile" }
  },
  {
    "index_key": 1,
    "attributes": { "display_name": "joseph" }
  },
  {
    "index_key": 2,
    "attributes": { "display_name": "mudathir" }
  }
]
```

The `index_key` is a **number**. That number is the only thing joining your configuration to the real Azure object. Reorder the list and every mapping is wrong.



On Azure AD users this is annoying. It could be genuinely dangerous anywhere the resource holds **state** or takes time to build — databases, VMs with data on them, storage accounts. Inserting one item at the top of a list could trigger the destruction and recreation of **every** resource after it. 

Destroy before we fix it:

*(Run from `~/terraform-training/03-lists-and-sets`)*
```bash
terraform destroy
# type: yes
```

---

#### Part 3 (≈25 min) — Fixing it with `for_each`

Update **main.tf** with new syntax.

**main.tf**
```tf
variable "names" {
  default = ["bukayo", "emile", "joseph", "mudathir", "guled"]
}

resource "azuread_user" "my_azuread_users" {
  # OLD — commented out
  #   count               = length(var.names)
  #   user_principal_name = "${var.names[count.index]}@jbloggs.onmicrosoft.com"

  # NEW CONFIG
  for_each            = toset(var.names)
  user_principal_name = "${each.value}@jbloggs.onmicrosoft.com"
  display_name        = each.value
  mail_nickname       = each.value
  password            = "ChangeMe123!ChangeMe"
}
```

The changes:

- `for_each` replaces `count`. The other iteration meta-argument, working over a **set or a map** rather than a number
- `toset(var.names)` converts our list to a **set**. `for_each` requires unique values, and a list can contain duplicates — so we convert. (A set is unordered and unique-only, exactly like a Python `Set`)
- `each.value` replaces `var.names[count.index]`. Inside a `for_each` block you get `each.value` (the current item) and `each.key`. For a set, key and value are the same thing

*(Run from `~/terraform-training/03-lists-and-sets`)*
```bash
terraform apply
```

Four resources — and notice **the order doesn't match your list**. (Unlikely that it'll match)

**Sets prioritise uniqueness, not order.** They're implemented with a **hash table**, which doesn't preserve insertion order.

**SIDE TANGENT**
- **Hashing** — each element runs through a hash function, turning it into a numeric fingerprint
- **Storage** — that fingerprint is used as an address in a table
- **Lookup** — to check membership, hash it and jump straight to that address

Extremely fast lookups; the price is that ordering isn't retained.

- Type: `yes`

Now look at the state file again:

**terraform.tfstate**
```tf
"instances": [
  {
    "index_key": "bukayo",              # <-- A STRING. The value itself.
    "attributes": { "display_name": "emile" }
  },
  {
    "index_key": "emile",
    "attributes": { "display_name": "romeo" }
  },
  {
    "index_key": "guled",
    "attributes": { "display_name": "simon" }
  }
]
```

**`index_key` is now a string — the value itself.** That's the whole fix. Each resource is tracked by **what it is**, not **where it sat**.

Prove it. Add a name at the front:

**main.tf**
```tf
variable "names" {
  default = ["eberechi", "bukayo", "emile", "joseph", "mudathir", "guled"]
}
```

*(Run from `~/terraform-training/03-lists-and-sets`)*
```bash
terraform apply
```
![intro-to-terraform-59](./resources/intro-to-terraform-59.png)

**1 to add, 0 to change.** Exactly what a human would expect.

- Type: `yes`

And removal behaves properly too:

**main.tf**
```tf
variable "names" {
  default = ["mudathir", "guled"]
}
```

*(Run from `~/terraform-training/03-lists-and-sets`)*
```bash
terraform apply
```

It identifies precisely which users to remove and leaves the rest alone.

- Type: `yes`

**The rule to take away: prefer `for_each` over `count` whenever the things you're creating have a meaningful identity.** Reserve `count` for genuinely interchangeable resources, or for conditionally creating something:

```tf
count = var.enable_backup ? 1 : 0     # a ternary — same as JavaScript
```

---

#### Part 4 (≈25 min) — Maps: richer data per resource

A set gives one value per resource. What if each user needs a country *and* a department?

*(Run from `~/terraform-training/03-lists-and-sets`)*
- Run: `terraform destroy` → type `yes`
- Run: `cd ..`

*(Run from `~/terraform-training`)*
- Run: `mkdir 04-maps` → **cd inside**

*(Run from `~/terraform-training/04-maps`)*
- Run: `touch main.tf`

Copy the config across from `03-lists-and-sets`, then convert the variable from a list to a **map**:

**04-maps/main.tf**
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

# UPDATED — square brackets [ ] become curly braces { }
variable "users" {
  default = {
    emile : "England",
    monia : "Brazil"
  }
}

resource "azuread_user" "my_azuread_users" {
  for_each            = var.users
  user_principal_name = "${each.key}@jbloggs.onmicrosoft.com"
  display_name        = each.key
  mail_nickname       = each.key
  password            = "ChangeMe123!ChangeMe"
  country             = each.value
}
```

*(Run from `~/terraform-training/04-maps`)*
```bash
terraform init
```

What changed:

- **`[ ]` became `{ }`** — the syntactic difference between a list and a map
- A map is **key/value pairs**, like a JavaScript object. Key is the username, value the country
- `for_each = var.users` — **no `toset()` needed**. Map keys are already unique by definition
- `each.key` is now the username, `each.value` the country. With a set they were the same; with a map they're properly distinct
- Renamed from `names` to `users`, because it holds more than names. **Name things for what they contain**

Explore it:

*(Run from `~/terraform-training/04-maps`)*
```bash
terraform console
```

```
var.users
var.users.sarah            # dot notation
var.users["sarah"]         # bracket notation — identical result
keys(var.users)            # just the keys
values(var.users)          # just the values
lookup(var.users, "emile") # find a value by key
```

**ASK YOURSELF** <br>
Both `.monia` and `["monia"]` work. Where else is that true? <br>
**ANSWER** <br>
**JavaScript objects** — `obj.monia` and `obj["monia"]` are interchangeable, with the same caveat that bracket notation is required for keys that aren't valid identifiers. `keys()` and `values()` are `Object.keys()` and `Object.values()`. HCL is borrowing your existing mental model.

Exit with `Ctrl + C`, then apply:

*(Run from `~/terraform-training/04-maps`)*
```bash
terraform apply
# type: yes
```

*(In the Azure Portal — Microsoft Entra ID → Users)* — both users exist, with countries set.

- *You'll find this by clicking on the created user name and selecting 'Properties' on the horizontal menu.*
- *It should appear under 'Contact Information' -> 'Country or region'*

Check the state (**terraform.tfstate**): `index_key` is the username, same as with a set.

**Now nest a map inside the map**, so each user carries multiple attributes:

**main.tf**
```tf
variable "users" {
  default = {
    # UPDATED — the value is now ANOTHER MAP
    emile : { country : "England" },
    monia : { country : "Brazil" }
  }
}
```

**ASK YOURSELF** <br>
The resource says `country = each.value`. How do we reach the country now? <br>
**ANSWER** <br>
`each.value.country` — `each.value` is now an object, so you chain onto it, exactly as in JavaScript.

```tf
resource "azuread_user" "my_azuread_users" {
  [ . . . ]
  # UPDATED
  country             = each.value.country
}
```

*(Run from `~/terraform-training/04-maps`)*
```bash
terraform apply
# type: yes
```

**No changes** — the resulting values are identical, even though the route to them changed. **Terraform compares results, not the expressions that produced them.**

Now the payoff — add another attribute:

**main.tf**
```tf
variable "users" {
  default = {
    emile : { country : "England", department : "Training" },
    monia : { country : "Brazil", department : "Training" }
  }
}

resource "azuread_user" "my_azuread_users" {
  [ . . . ]
  country             = each.value.country
  # UPDATED
  department          = each.value.department
}
```

Both `country` and `department` are **native, typed attributes** on `azuread_user` — first-class fields, not entries stuffed into a generic tags map.

*(Run from `~/terraform-training/04-maps`)*
```bash
terraform apply
# type: yes
```

An in-place update adding the attribute.

*Try finding the Department value added to the User in the Azure Portal*

---

#### Part 5 — Stretch goals

1. **A third user with different values.** Add someone with a different country and department, apply, confirm only one resource is created
2. **Optional attributes.** Give one user a `job_title` and the others none. *(Hint: `lookup(each.value, "job_title", null)` returns a default when the key is absent)*
3. **An output over the map.** List every created user's `user_principal_name`. *(Hint: `values(azuread_user.my_azuread_users)[*].user_principal_name` — `[*]` is the **splat operator**, pulling one attribute from every element)*
4. **Drift detection.** In the Portal, manually change one user's department. Then run `terraform plan` and see Terraform detect that Actual no longer matches Desired

**Solution**

**Stretch 1 and 2:**
```tf
variable "users" {
  default = {
    emile : { country : "England", department : "Training", job_title : "Trainer" },
    monia : { country : "Brazil", department : "Training" }
    pierre : { country : "Jamaica", department : "People Experience" }
  }
}

resource "azuread_user" "my_azuread_users" {
  for_each            = var.users
  user_principal_name = "${each.key}@jbloggs.onmicrosoft.com"
  display_name        = each.key
  mail_nickname       = each.key
  password            = "ChangeMe123!ChangeMe"
  country             = each.value.country
  department          = each.value.department

  # lookup(map, key, default) — returns the default when the key is missing,
  # so users without a job_title don't error
  job_title           = lookup(each.value, "job_title", null)
}
```

`lookup(map, key, default)` is the same idea as `obj.key ?? default` in JavaScript.

**Stretch 3:**
```tf
output "all_user_principal_names" {
  # values() turns the map of resources into a list,
  # then [*] pulls one attribute from every element
  value = values(azuread_user.my_azuread_users)[*].user_principal_name
}
```

`[*]` is doing the job of `.map(u => u.userPrincipalName)`.

*(Run from `~/terraform-training/04-maps`)*
```bash
terraform apply     # -> 1 to add (pierre), 1 to change (emile gains a job_title)
# type: yes
terraform output all_user_principal_names
```

**Stretch 4 — drift detection.**

*(In the Azure Portal — Microsoft Entra ID → Users → pierre)* — change **Department** to `Marketing` and save.

*(Run from `~/terraform-training/04-maps`)*
```bash
terraform plan
```

The plan reports **1 to change**, showing `department: "Marketing" -> "Training"`. Terraform refreshed Actual State, found it no longer matches Desired State in your code, and proposes putting it back. Run `terraform apply` and the manual change is reverted.

**This is the single strongest argument for Infrastructure as Code.** Your `.tf` files aren't just a record of what you built — **they're the authority.** Anything anyone does by hand gets detected and corrected. That's the ClickOps drift problem from Session 1, solved.

**ASK YOURSELF** <br>
Terraform just silently reverted someone's manual change. Is that always what you want? <br>
**ANSWER** <br>
Mostly yes — that's the point. But it has a real consequence: **the Portal effectively becomes read-only** for anything Terraform manages. Someone making an emergency fix at 3am in the Portal will find it silently undone by the next pipeline run. Which means the team has to *agree* that Terraform is the authority, and that emergency fixes go through the code. It's a cultural commitment as much as a technical one — the same commitment as "we don't push directly to `main`".
