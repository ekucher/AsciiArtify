# AsciiArtify PoC: Argo CD on k3d

## 1. Мета PoC

Мета цього Proof of Concept — практично підтвердити можливість розгорнути GitOps-систему **Argo CD** у локальному Kubernetes-кластері, створеному за допомогою **k3d**, який було обрано на етапі Concept для PoC AsciiArtify.

Argo CD — declarative GitOps continuous delivery tool for Kubernetes. У межах цього PoC перевіряються:

- створення multi-node Kubernetes-кластера через k3d;
- встановлення Argo CD в окремий namespace `argocd`;
- готовність усіх основних компонентів Argo CD;
- отримання initial admin credentials без збереження пароля у Git;
- локальний доступ команди до Argo CD Web UI через `kubectl port-forward`;
- доступ до Web UI з Windows, коли Kubernetes/k3d запущені всередині WSL2.

> Для PoC використовується стандартний non-HA manifest Argo CD. Він підходить для evaluation/demo/testing. Для production слід використовувати pinned version та HA-конфігурацію.

---

## 2. Передумови

Потрібні:

- Docker-compatible container runtime;
- `kubectl`;
- `k3d`;
- WSL2/Linux environment (для цього PoC використовувався Ubuntu у WSL2);
- доступ до GitHub/Internet для завантаження Argo CD manifests та container images.

Перевірка:

```bash
docker --version
kubectl version --client
k3d version
```

У практичному PoC використовувались:

- Docker 29.x;
- kubectl v1.36.1;
- k3d v5.9.0;
- k3s v1.35.5-k3s1;
- Argo CD v3.5.2.

Версію Argo CD можна перевірити так:

```bash
kubectl get deployment argocd-server \
  -n argocd \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
echo
```

---

## 3. Створення Kubernetes-кластера

Створюємо кластер з одним server node та двома agent nodes:

```bash
k3d cluster create asciiartify \
  --servers 1 \
  --agents 2 \
  --wait
```

Перевірка контексту та нод:

```bash
kubectl config current-context
kubectl get nodes -o wide
```

Очікуваний context:

```text
k3d-asciiartify
```

Практично підтверджено, що всі три Kubernetes nodes переходять у стан `Ready`:

```text
k3d-asciiartify-server-0   Ready
k3d-asciiartify-agent-0    Ready
k3d-asciiartify-agent-1    Ready
```

---

## 4. Встановлення Argo CD

Створюємо namespace idempotent-командою, щоб повторний запуск не завершувався помилкою `AlreadyExists`:

```bash
kubectl create namespace argocd \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

Встановлюємо Argo CD через офіційний stable manifest:

```bash
kubectl apply \
  -n argocd \
  --server-side \
  --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Параметри `--server-side --force-conflicts` використовуються відповідно до актуальної документації Argo CD, зокрема через розмір CRD.

> Для production замість плаваючої гілки `stable` рекомендується закріпити конкретну версію Argo CD.

---

## 5. Перевірка готовності Argo CD

Очікуємо готовності всіх pod-ів:

```bash
kubectl wait \
  --for=condition=Ready \
  pod \
  --all \
  -n argocd \
  --timeout=300s
```

Потім перевіряємо:

```bash
kubectl get pods -n argocd -o wide
kubectl get svc -n argocd
```

У практичному PoC успішно запущено всі основні компоненти:

```text
argocd-application-controller      1/1 Running
argocd-applicationset-controller  1/1 Running
argocd-dex-server                 1/1 Running
argocd-notifications-controller   1/1 Running
argocd-redis                      1/1 Running
argocd-repo-server                1/1 Running
argocd-server                     1/1 Running
```

Сервіс Web/API інтерфейсу:

```text
argocd-server   ClusterIP   80/TCP,443/TCP
```

Додаткова перевірка всіх ресурсів:

```bash
kubectl get all -n argocd
```

---

## 6. Отримання initial admin password

Username за замовчуванням:

```text
admin
```

Initial password зберігається у Kubernetes Secret і отримується командою:

```bash
kubectl -n argocd \
  get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' |
  base64 -d

echo
```

> **Security:** реальний пароль не повинен зберігатися у Git, документації, shell scripts або demo-файлах.

Після першого входу initial password рекомендується змінити. Для ephemeral PoC альтернативою є видалення всього k3d-кластера після завершення демонстрації.

---

## 7. Доступ до Argo CD Web UI

За замовчуванням `argocd-server` має тип `ClusterIP`, тому для локального PoC зовнішня публікація сервісу не потрібна.

### 7.1. Звичайний локальний доступ

Якщо `kubectl` працює безпосередньо на хості або WSL localhost forwarding працює коректно:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Після цього Web UI доступний за адресою:

```text
https://localhost:8080
```

### 7.2. Доступ з Windows до Argo CD у WSL2

У цьому PoC k3d/Kubernetes запущені всередині WSL2. Якщо Windows-браузер не може відкрити `https://localhost:8080`, port-forward потрібно прив'язати до всіх інтерфейсів WSL:

```bash
kubectl port-forward \
  --address 0.0.0.0 \
  svc/argocd-server \
  -n argocd \
  8080:443
```

Очікуваний результат:

```text
Forwarding from 0.0.0.0:8080 -> 8080
```

Перевірка всередині WSL:

```bash
curl -k https://127.0.0.1:8080/
```

Якщо повертається HTML-сторінка Argo CD, port-forward працює.

Визначаємо IP WSL:

```bash
hostname -I
```

Потрібно використовувати першу WSL-адресу, наприклад:

```text
172.x.x.x
```

> WSL2 IP є динамічним і може змінитися після перезапуску WSL/Windows, тому його не слід жорстко записувати у скрипти або документацію.

У Windows-браузері відкриваємо:

```text
https://<WSL-IP>:8080
```

Наприклад:

```text
https://172.x.x.x:8080
```

За потреби перевірити доступність порту з Windows PowerShell:

```powershell
Test-NetConnection <WSL-IP> -Port 8080
```

Очікується:

```text
TcpTestSucceeded : True
```

Через self-signed TLS certificate браузер може показати попередження. Для локального PoC це очікувана поведінка.

Дані для входу:

```text
Username: admin
Password: <отримати командою з Kubernetes Secret>
```

Port-forward process має залишатися запущеним, поки використовується Web UI.

---

## 8. Швидка demo-інструкція

Повний мінімальний сценарій для повторення PoC:

```bash
# 1. Create cluster
k3d cluster create asciiartify --servers 1 --agents 2 --wait

# 2. Verify Kubernetes
kubectl get nodes

# 3. Create namespace idempotently
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# 4. Install Argo CD
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 5. Wait until Argo CD is ready
kubectl wait --for=condition=Ready pod --all -n argocd --timeout=300s
kubectl get pods -n argocd

# 6. Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo

# 7. Expose Web UI from WSL2
kubectl port-forward --address 0.0.0.0 \
  svc/argocd-server -n argocd 8080:443
```

У другому WSL terminal:

```bash
curl -k https://127.0.0.1:8080/
hostname -I
```

Відкрити у Windows-браузері:

```text
https://<WSL-IP>:8080
```

Login:

```text
admin
```

Password отримати командою з кроку 6.

---

## 9. Результат PoC

Практично підтверджено:

- k3d успішно створює multi-node Kubernetes cluster для AsciiArtify;
- усі 3 Kubernetes nodes працюють у стані `Ready`;
- Argo CD успішно встановлюється в namespace `argocd`;
- усі 7 основних Argo CD pod-ів переходять у стан `Running/Ready`;
- фактично протестована версія Argo CD — `v3.5.2`;
- `argocd-server` доступний всередині кластера через `ClusterIP`;
- `curl -k https://127.0.0.1:8080/` через port-forward успішно повертає HTML Argo CD Web UI;
- для WSL2 документовано доступ із Windows через `--address 0.0.0.0` та динамічний WSL IP;
- initial admin password отримується з Kubernetes Secret і не потребує збереження у Git.

PoC підтверджує технічну можливість використовувати Argo CD як GitOps-систему для наступного етапу AsciiArtify — MVP.

---

## 10. Cleanup

Після завершення PoC весь локальний кластер можна видалити:

```bash
k3d cluster delete asciiartify
```

Це видаляє ephemeral Kubernetes environment разом із Argo CD та initial credentials.

---

## 11. Джерела

- Argo CD documentation: https://argo-cd.readthedocs.io/en/stable/
- Argo CD Getting Started: https://argo-cd.readthedocs.io/en/stable/getting_started/
- k3d documentation: https://k3d.io/
