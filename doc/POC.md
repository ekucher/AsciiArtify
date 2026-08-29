# AsciiArtify PoC: Argo CD on k3d

## 1. Мета PoC

Мета цього Proof of Concept — практично підтвердити можливість розгорнути GitOps-систему **Argo CD** у локальному Kubernetes-кластері, створеному за допомогою **k3d**, який було обрано на етапі Concept для PoC AsciiArtify.

Argo CD — declarative GitOps continuous delivery tool for Kubernetes. У межах цього PoC перевіряються:

- створення multi-node Kubernetes-кластера через k3d;
- встановлення Argo CD в окремий namespace `argocd`;
- готовність усіх основних компонентів Argo CD;
- отримання initial admin credentials без збереження пароля у Git;
- локальний доступ команди до Argo CD Web UI через `kubectl port-forward`.

> Для PoC використовується стандартний non-HA manifest Argo CD. Він підходить для evaluation/demo/testing. Для production слід використовувати pinned version та HA-конфігурацію.

---

## 2. Передумови

Потрібні:

- Docker-compatible container runtime;
- `kubectl`;
- `k3d`;
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
- k3s v1.35.5-k3s1.

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

Створюємо окремий namespace:

```bash
kubectl create namespace argocd
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

Після першого входу initial password рекомендується змінити.

---

## 7. Доступ до Argo CD Web UI

За замовчуванням `argocd-server` має тип `ClusterIP`, тому для локального PoC зовнішня публікація сервісу не потрібна.

Запускаємо port-forward:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Очікуваний результат:

```text
Forwarding from 127.0.0.1:8080 -> 8080
Forwarding from [::1]:8080 -> 8080
```

Після цього відкриваємо у браузері:

```text
https://localhost:8080
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

# 3. Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 4. Wait until Argo CD is ready
kubectl wait --for=condition=Ready pod --all -n argocd --timeout=300s
kubectl get pods -n argocd

# 5. Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo

# 6. Expose Web UI locally
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Відкрити:

```text
https://localhost:8080
```

Login:

```text
admin
```

Password отримати командою з кроку 5.

---

## 9. Результат PoC

Практично підтверджено:

- k3d успішно створює multi-node Kubernetes cluster для AsciiArtify;
- усі 3 Kubernetes nodes працюють у стані `Ready`;
- Argo CD успішно встановлюється в namespace `argocd`;
- усі 7 основних Argo CD pod-ів переходять у стан `Running/Ready`;
- `argocd-server` доступний всередині кластера через `ClusterIP`;
- локальний доступ до Web UI надається через `kubectl port-forward` без зміни типу Service;
- initial admin password отримується з Kubernetes Secret і не потребує збереження у Git.

Таким чином, Argo CD готовий як GitOps-платформа для наступного етапу — реалізації MVP AsciiArtify та declarative deployment застосунку з Git repository.

---

## 10. Cleanup

Після завершення локального PoC кластер можна повністю видалити:

```bash
k3d cluster delete asciiartify
```

Це видалить локальний Kubernetes cluster разом з Argo CD та initial credentials.

---

## 11. Джерела

- Argo CD documentation: https://argo-cd.readthedocs.io/en/stable/
- Getting Started: https://argo-cd.readthedocs.io/en/latest/getting_started/
- Local Argo CD setup: https://argo-cd.readthedocs.io/en/stable/try_argo_cd_locally/
- Installation options: https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/
- k3d documentation: https://k3d.io/
