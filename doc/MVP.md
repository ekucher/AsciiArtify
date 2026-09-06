# AsciiArtify MVP: автоматичне розгортання через Argo CD

## 1. Мета

Мета цього етапу — розгорнути MVP-застосунок `go-demo-app` у локальному Kubernetes-кластері `k3d-asciiartify` та підтвердити повний GitOps-цикл:

```text
Git commit -> GitHub -> Argo CD detects change -> automatic sync -> Kubernetes
```

На попередніх етапах для AsciiArtify було обрано **k3d/k3s** і перевірено встановлення Argo CD. На етапі MVP додається декларативний ресурс Argo CD `Application`, який:

- отримує Helm chart продукту з `den-vasyliev/go-demo-app`;
- отримує параметри середовища з репозиторію `ekucher/AsciiArtify`;
- розгортає продукт у namespace `go-demo`;
- автоматично синхронізує зміни з Git;
- видаляє ресурси, які було видалено з Git (`prune`);
- виправляє ручні зміни у кластері (`selfHeal`).

---

## 2. Реалізовані файли

| Файл | Призначення |
|---|---|
| `argocd/go-demo-app.yaml` | Декларативний Argo CD `Application` |
| `argocd/values/go-demo-app.yaml` | Параметри MVP-середовища та контрольна зміна для GitOps-демо |
| `demo/mvp-demo.sh` | Команди перевірки, port-forward, спостереження та self-heal demo |
| `doc/MVP.md` | Опис архітектури, розгортання та відеодемонстрації |

Секрети, паролі та kubeconfig у Git не зберігаються.

---

## 3. GitOps-архітектура

Argo CD Application використовує два Git-джерела:

1. `https://github.com/den-vasyliev/go-demo-app.git`, каталог `helm` — upstream Helm chart продукту.
2. `https://github.com/ekucher/AsciiArtify.git`, файл `argocd/values/go-demo-app.yaml` — контрольовані командою параметри середовища.

Такий поділ дозволяє не копіювати upstream chart і водночас виконувати власні контрольні коміти для демонстрації автоматичної синхронізації.

Ціль розгортання:

```text
Cluster:   https://kubernetes.default.svc
Namespace: go-demo
Release:   go-demo
```

---

## 4. Передумови

Потрібні:

- Docker-compatible runtime;
- `k3d`;
- `kubectl`;
- Git;
- кластер `asciiartify` з контекстом `k3d-asciiartify`;
- Argo CD у namespace `argocd` відповідно до `doc/POC.md`.

Перевірка:

```bash
docker --version
k3d version
kubectl version --client
git --version
kubectl config current-context
kubectl get nodes
kubectl get pods -n argocd
```

Очікуваний Kubernetes context:

```text
k3d-asciiartify
```

Якщо кластер після PoC було видалено, його можна відновити:

```bash
k3d cluster create asciiartify \
  --servers 1 \
  --agents 2 \
  --wait
```

Встановлення Argo CD, якщо його ще немає у кластері:

```bash
kubectl create namespace argocd \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl apply \
  -n argocd \
  --server-side \
  --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait \
  --for=condition=Ready \
  pod \
  --all \
  -n argocd \
  --timeout=300s
```

---

## 5. Створення Argo CD Application

Команди виконуються з кореня репозиторію AsciiArtify:

```bash
git clone https://github.com/ekucher/AsciiArtify.git
cd AsciiArtify
chmod +x demo/mvp-demo.sh
./demo/mvp-demo.sh preflight
./demo/mvp-demo.sh apply
```

Альтернативна коротка команда:

```bash
kubectl apply -f argocd/go-demo-app.yaml
```

Перевірка Application:

```bash
kubectl get application go-demo-app -n argocd
kubectl describe application go-demo-app -n argocd
```

Очікуваний стан після синхронізації:

```text
NAME          SYNC STATUS   HEALTH STATUS
go-demo-app   Synced        Healthy
```

Початкова синхронізація може тривати кілька хвилин, оскільки Kubernetes завантажує images усіх компонентів продукту.

---

## 6. Перевірка розгорнутого MVP

Перегляд усіх компонентів:

```bash
./demo/mvp-demo.sh status
```

Або без допоміжного скрипту:

```bash
kubectl get deployments,statefulsets,pods,services -n go-demo -o wide
kubectl get events -n go-demo --sort-by=.lastTimestamp
```

Очікуються frontend, API, ASCII processor, image processor, data service, Redis, MySQL, NATS та API gateway.

Для доступу до frontend:

```bash
./demo/mvp-demo.sh app-ui
```

Відкрити у браузері:

```text
http://localhost:8888
```

Перевірка через `curl`:

```bash
curl http://localhost:8888/
curl http://localhost:8888/version
```

Якщо застосунок працює у WSL2 і Windows не відкриває `localhost`, можна виконати port-forward на всіх інтерфейсах:

```bash
kubectl port-forward \
  --address 0.0.0.0 \
  -n go-demo \
  svc/go-demo-front \
  8888:80
```

Після цього у Windows потрібно відкрити `http://<WSL-IP>:8888`, де адресу WSL можна отримати командою `hostname -I`.

---

## 7. Доступ до Argo CD Web UI

Отримати initial admin password:

```bash
kubectl -n argocd \
  get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo
```

Запустити port-forward:

```bash
./demo/mvp-demo.sh argocd-ui
```

Відкрити:

```text
https://localhost:8080
```

Дані для входу:

```text
Username: admin
Password: <отриманий із Kubernetes Secret>
```

Self-signed TLS warning для локального PoC є очікуваним. Initial password не можна показувати у відео або додавати в Git.

---

## 8. Демонстрація автоматичної синхронізації

### 8.1. Початковий стан

В окремому terminal запустити спостереження:

```bash
./demo/mvp-demo.sh watch
```

Початкове значення у `argocd/values/go-demo-app.yaml`:

```yaml
front:
  replicas: 1
```

Перевірка:

```bash
kubectl get deployment go-demo-front -n go-demo
```

### 8.2. Git-зміна

Змінити кількість frontend replicas з `1` на `2`:

```yaml
front:
  replicas: 2
```

Створити й опублікувати коміт:

```bash
git add argocd/values/go-demo-app.yaml
git commit -m "demo: scale go-demo frontend to two replicas"
git push origin main
```

Нічого вручну в Argo CD натискати не потрібно. Після виявлення нового commit Application короткочасно перейде у `OutOfSync`, автоматично виконає sync і повернеться у `Synced`.

> Стандартне polling-виявлення Git-зміни може тривати до кількох хвилин. У відео можна скоротити очікування, натиснувши `Refresh` у Web UI; кнопку `Sync` натискати не потрібно, адже саме синхронізація має відбутися автоматично.

Очікуваний результат:

```bash
kubectl get deployment go-demo-front -n go-demo
kubectl get pods -n go-demo -l app=go-demo-front
```

```text
NAME            READY   UP-TO-DATE   AVAILABLE
go-demo-front   2/2     2            2
```

Це підтверджує цикл Git -> Argo CD -> Kubernetes без ручного `kubectl apply` для продукту.

---

## 9. Демонстрація self-heal

Додаткова перевірка створює drift — ручну зміну live state поза Git:

```bash
./demo/mvp-demo.sh drift
```

Скрипт тимчасово масштабує frontend до трьох replicas:

```bash
kubectl scale deployment go-demo-front -n go-demo --replicas=3
```

Оскільки в Git залишається значення `2`, Argo CD виявить drift і автоматично поверне Deployment до двох replicas. Це демонструє роботу `selfHeal: true`.

---

## 10. Сценарій відеодемонстрації

Рекомендована тривалість: **4–6 хвилин**.

1. Показати GitHub-репозиторій AsciiArtify та файли `doc/MVP.md`, `argocd/go-demo-app.yaml`, `argocd/values/go-demo-app.yaml`.
2. У terminal виконати `./demo/mvp-demo.sh preflight` і показати три Kubernetes nodes та pod-и Argo CD.
3. Виконати `./demo/mvp-demo.sh apply`.
4. Відкрити Argo CD Web UI та показати Application `go-demo-app` у стані `Synced/Healthy`.
5. Виконати `./demo/mvp-demo.sh status` і показати ресурси namespace `go-demo`.
6. Відкрити MVP за адресою `http://localhost:8888`.
7. Змінити `front.replicas` з `1` на `2`, виконати `git commit` і `git push`.
8. Показати, як Argo CD без натискання `Sync` отримує нову revision та повертається у `Synced`.
9. Показати два frontend pod-и командою `kubectl get pods -n go-demo -l app=go-demo-front`.
10. За наявності часу виконати `./demo/mvp-demo.sh drift` і показати автоматичне self-heal.

Під час запису не показувати пароль Argo CD, GitHub tokens, kubeconfig або інші credentials.

### Відео MVP

Після запису додати сюди клікабельне посилання:

```text
MVP demo: <URL відео>
```

---

## 11. Troubleshooting

### Application не переходить у Synced

```bash
kubectl describe application go-demo-app -n argocd
kubectl logs -n argocd deployment/argocd-repo-server --tail=100
kubectl logs -n argocd statefulset/argocd-application-controller --tail=100
```

### Pod-и не переходять у Running

```bash
kubectl get pods -n go-demo
kubectl describe pod <pod-name> -n go-demo
kubectl logs <pod-name> -n go-demo --all-containers --tail=100
kubectl get events -n go-demo --sort-by=.lastTimestamp
```

Стани `ErrImagePull` або `ImagePullBackOff` означають, що потрібно перевірити доступ до container registry та існування image/tag в upstream chart.

### Windows не відкриває WSL2 port-forward

```bash
hostname -I
kubectl port-forward --address 0.0.0.0 \
  -n go-demo svc/go-demo-front 8888:80
```

У Windows PowerShell:

```powershell
Test-NetConnection <WSL-IP> -Port 8888
```

### Argo CD ще не побачив Git-коміт

Без webhook Argo CD періодично опитує Git. Слід зачекати до трьох хвилин або виконати лише refresh кешу:

```bash
kubectl annotate application go-demo-app \
  -n argocd \
  argocd.argoproj.io/refresh=hard \
  --overwrite
```

Ця команда оновлює інформацію про Git revision, але не виконує ручну синхронізацію.

### Попередження Helm lint для upstream chart

`go-demo-app` — legacy chart, який використовує `apiVersion: v1` і vendored subcharts без повного переліку dependencies у `Chart.yaml`. Тому локальна команда `helm lint` може показати попередження/помилки metadata, хоча `helm template` успішно генерує ресурси для Argo CD.

У upstream `data-deploy.yaml` також залишився старий дубльований YAML-ключ `name`. Це технічний борг продуктового репозиторію, а не зміна AsciiArtify. Перед демонстрацією потрібно орієнтуватися на фактичний стан Application у Argo CD та Kubernetes events:

```bash
kubectl get application go-demo-app -n argocd
kubectl get events -n go-demo --sort-by=.lastTimestamp
```

Якщо upstream chart буде модернізовано, override-файл `argocd/values/go-demo-app.yaml` і Argo CD Application змінювати не потрібно.

---

## 12. Cleanup

Видалити Application разом із керованими ресурсами:

```bash
./demo/mvp-demo.sh cleanup
```

За потреби видалити весь ephemeral cluster:

```bash
k3d cluster delete asciiartify
```

---

## 13. Результат

Підготовлена GitOps-конфігурація MVP:

- Argo CD Application декларативно зберігається у Git;
- upstream Helm chart не дублюється у репозиторії AsciiArtify;
- namespace `go-demo` створюється автоматично;
- зміни Git автоматично застосовуються до Kubernetes;
- `prune` видаляє ресурси, вилучені з Git;
- `selfHeal` виправляє ручний drift у кластері;
- продукт доступний локально через Kubernetes Service та `port-forward`.

Репозиторій для надсилання на перевірку:

```text
https://github.com/ekucher/AsciiArtify
```

---

## 14. Джерела

- Argo CD Automated Sync Policy: https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/
- Argo CD Declarative Setup: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/
- Argo CD Multiple Sources: https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/
- Argo CD Getting Started: https://argo-cd.readthedocs.io/en/stable/getting_started/
- go-demo-app: https://github.com/den-vasyliev/go-demo-app
- k3d documentation: https://k3d.io/
