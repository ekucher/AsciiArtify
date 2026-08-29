# AsciiArtify Concept: вибір локального Kubernetes для PoC

## 1. Вступ

Стартап **AsciiArtify** планує створити застосунок, який перетворює зображення в ASCII-art за допомогою Machine Learning. Для розробки та тестування застосунку команда планує використовувати Kubernetes.

Для локального Kubernetes-середовища розглядаються три інструменти:

- **minikube** — локальний Kubernetes, орієнтований на навчання, розробку та тестування. Кластер може працювати у VM, контейнерах або безпосередньо на Linux-хості залежно від драйвера.
- **kind (Kubernetes IN Docker)** — інструмент Kubernetes SIGs, який запускає Kubernetes-ноди як контейнери. Особливо добре підходить для автоматизованого тестування та CI.
- **k3d** — легкий wrapper для запуску **k3s** у контейнерах. k3s — lightweight-дистрибутив Kubernetes, тому k3d дозволяє дуже швидко створювати локальні multi-node кластери.

> **Уточнення:** k3d запускає **k3s**, а не Rancher Kubernetes Engine (RKE).

Метою цього Concept є вибір інструменту для PoC AsciiArtify з урахуванням швидкості запуску, простоти використання, автоматизації, локальної розробки, multi-node сценаріїв, Docker licensing та можливості використання Podman.

---

## 2. Критерії оцінювання

Для порівняння використано такі критерії:

1. Підтримувані операційні системи та CPU-архітектури.
2. Простота встановлення та використання.
3. Швидкість створення і видалення кластеру.
4. Multi-node підтримка.
5. Можливість автоматизації та використання в CI/CD.
6. Додаткові можливості: dashboard, addons, ingress, registry, load balancer.
7. Робота з Docker та Podman.
8. Відповідність звичайному Kubernetes.
9. Документація та підтримка спільноти.
10. Ліцензійні ризики.

---

## 3. Порівняльна таблиця

| Характеристика | minikube | kind | k3d |
|---|---|---|---|
| Основне призначення | Локальна розробка, навчання, тестування | Тестування Kubernetes, CI/CD, локальна розробка | Швидка локальна розробка та PoC на базі k3s |
| Kubernetes implementation | Kubernetes | Kubernetes, ноди створюються через kubeadm | k3s |
| ОС | Linux, macOS, Windows | Linux, macOS, Windows | Linux, macOS, Windows |
| Архітектури | x86-64, ARM64; на Linux також доступні інші збірки | Офіційні pre-built node images: AMD64, ARM64 | Основні desktop/server архітектури, зокрема AMD64/ARM64 |
| Запуск нод | VM, container driver або bare-metal залежно від ОС/драйвера | Контейнери | Контейнери |
| Multi-node | Так | Так, включно з HA topology | Так: server та agent nodes |
| Швидкість створення | Середня | Висока | Дуже висока |
| Споживання ресурсів | Вище, особливо з VM driver | Низьке/середнє | Низьке |
| Автоматизація | CLI, profiles, config | Дуже добре підходить для CI | CLI, config files, добре підходить для scripts/CI |
| Dashboard | Вбудована команда `minikube dashboard` | Немає вбудованого dashboard | Немає власного dashboard |
| Addons | Велика кількість готових addons | Переважно встановлюються вручну | Використовуються можливості k3s/Helm/manifests |
| Ingress | Є addon | Встановлюється окремо | k3s зазвичай постачається з Traefik |
| Local registry | Є addon/окреме налаштування | Можна підключити локальний registry | Вбудовані команди керування локальним registry |
| Load balancer | `minikube tunnel` | Потребує додаткового налаштування | k3d створює proxy/load-balancer для кластеру |
| Завантаження локальних images | `minikube image load` | `kind load docker-image` | `k3d image import` |
| Docker | Підтримується | Підтримується | Основний runtime/API path |
| Podman | Є driver, позначений experimental | Документована підтримка provider; rootless має обмеження | Підтримка через Docker API compatibility, experimental |
| Production parity | Висока для локальної розробки, залежить від driver/config | Висока для upstream Kubernetes testing | Нижча, якщо production використовує повний upstream Kubernetes, оскільки k3s має власні defaults |
| Документація/спільнота | Дуже велика | Велика, Kubernetes SIG Testing | Велика cloud-native/k3s спільнота |
| Ліцензія інструменту | Apache-2.0 | Apache-2.0 | MIT |
| Найкращий сценарій | Навчання, developer workstation, addons/dashboard | CI, Kubernetes integration tests | PoC, lightweight local clusters, швидкий development loop |

---

## 4. Аналіз інструментів

### 4.1. minikube

**minikube** створений насамперед для простого локального запуску Kubernetes.

### Переваги

- Дуже проста початкова конфігурація.
- Працює на Linux, macOS та Windows.
- Велика кількість driver-ів: Docker, Hyper-V, KVM, VirtualBox, QEMU, Podman тощо.
- Підтримує multi-node кластери.
- Має зручну систему addons.
- Є вбудована команда для Kubernetes Dashboard.
- Зручні команди `minikube service`, `minikube tunnel`, `minikube image load`.
- Дуже велика документація та спільнота.

### Недоліки

- При використанні VM driver споживає більше RAM та CPU.
- Створення кластеру зазвичай повільніше, ніж у kind/k3d.
- Частина поведінки залежить від обраного driver.
- Podman driver офіційно позначений як experimental.
- Для CI зазвичай є простіші та легші рішення.

### Коли обирати

minikube є хорошим вибором для розробника, який тільки знайомиться з Kubernetes, або коли важливі готові addons, dashboard і зручні developer-oriented команди.

---

### 4.2. kind

**kind** означає **Kubernetes IN Docker**. Ноди кластеру запускаються як контейнери.

### Переваги

- Дуже швидке створення і видалення кластерів.
- Низьке споживання ресурсів.
- Підтримує multi-node та HA topologies.
- Добре відтворюється через YAML config.
- Дуже добре інтегрується в CI/CD.
- Використовується Kubernetes community для тестування Kubernetes.
- Підтримує Docker, Podman та nerdctl.
- Можна завантажувати локально зібрані images через `kind load docker-image`.
- Близька поведінка до upstream Kubernetes.

### Недоліки

- Менше developer-friendly addons, ніж у minikube.
- Немає власного dashboard.
- Ingress, metrics-server та інші компоненти зазвичай потрібно встановлювати окремо.
- Rootless Podman/Docker вимагає коректного cgroup v2 та має окремі обмеження.
- Networking на Windows/macOS залежить від container runtime/VM layer.

### Коли обирати

kind є оптимальним для автоматизованих Kubernetes integration tests та CI. Також це найцікавіший варіант, якщо потрібно мінімізувати залежність від Docker Desktop і використовувати Podman.

---

### 4.3. k3d

**k3d** запускає lightweight Kubernetes-дистрибутив **k3s** у контейнерах.

### Переваги

- Дуже швидкий старт кластеру.
- Низьке споживання ресурсів.
- Легко створювати server/agent multi-node topology.
- Зручне port mapping.
- Автоматично створюється load-balancer/proxy.
- Зручна інтеграція локального container registry.
- Є `k3d image import`.
- Зручний YAML configuration.
- k3s включає багато компонентів, потрібних для невеликого кластеру.
- Добре підходить для коротких PoC та developer environments.

### Недоліки

- Це k3s, а не повний upstream Kubernetes distribution.
- Деякі default components та налаштування можуть відрізнятися від production Kubernetes.
- Основний шлях роботи передбачає Docker-compatible API.
- Podman support позначений як experimental і не гарантується для всіх конфігурацій.
- Для перевірки специфічної поведінки upstream Kubernetes kind може бути кращим.

### Коли обирати

k3d є дуже хорошим вибором для PoC, коли важливі швидкість, простота, низьке споживання ресурсів і можливість швидко створювати multi-node cluster.

---

## 5. Docker licensing та Podman

Потрібно розділяти **Docker Engine/Moby** та **Docker Desktop**.

Docker Desktop має окремі subscription terms. На момент підготовки Concept Docker Desktop безкоштовний для:

- персонального використання;
- освіти;
- non-commercial open-source проєктів;
- компаній, які одночасно мають **менше 250 співробітників** і **менше 10 млн USD річного доходу**.

Для більшої компанії або при виході за ці межі для комерційного використання Docker Desktop потрібна платна subscription.

Для молодого AsciiArtify це не створює негайної проблеми, якщо стартап відповідає free-tier умовам, але залежність від Docker Desktop потрібно враховувати як майбутній licensing risk.

При цьому Docker Engine/Moby залишається open-source і його ліцензування не тотожне Docker Desktop.

### Podman як альтернатива

**Podman** — open-source OCI container engine, який:

- не вимагає постійного central daemon;
- підтримує rootless mode;
- має Docker-compatible CLI/API сценарії;
- може використовуватися замість Docker у частині developer workflows.

Поточний стан для трьох інструментів:

- **minikube + Podman** — підтримується, але Podman driver позначений experimental;
- **kind + Podman** — має документований provider та rootless сценарій; потрібен cgroup v2 та додаткові налаштування;
- **k3d + Podman** — використовує Docker API compatibility layer Podman, але підтримка офіційно позначена experimental.

### Рекомендована стратегія

Для PoC:

1. Використовувати **k3d**.
2. На Linux бажано використовувати Docker Engine без необхідності Docker Desktop.
3. На developer workstation Docker Desktop можна використовувати, якщо AsciiArtify відповідає free-tier ліцензійним умовам.
4. Kubernetes manifests не повинні залежати від специфічних Docker Desktop можливостей.
5. Як fallback варто періодично перевіряти ті самі manifests у **kind + Podman**.

Якщо вимога **повністю уникнути Docker Desktop/Docker API dependency** є жорсткою вже на старті, більш консервативним вибором буде **kind + Podman**, а не k3d + Podman.

---

## 6. Рекомендація для AsciiArtify

Для PoC рекомендовано **k3d**.

Причини:

1. Дуже швидке створення локального Kubernetes кластеру.
2. Низьке споживання ресурсів.
3. Просте створення multi-node topology.
4. Вбудований load-balancer/proxy.
5. Зручна підтримка local registry.
6. Простий імпорт локальних container images.
7. Хороша придатність для короткого development feedback loop.
8. k3s достатньо функціональний для PoC AsciiArtify.

При цьому:

- **kind** рекомендується додатково використовувати в CI для Kubernetes integration tests;
- **minikube** рекомендується для навчання, демонстрацій та сценаріїв, де потрібні dashboard/addons.

Таким чином, вибір не обов'язково повинен бути взаємовиключним:

```text
Developer PoC: k3d
       |
       v
GitHub -> CI tests: kind
       |
       v
Production Kubernetes
```

---

## 7. Практичне ознайомлення

Перед записом фінального demo доцільно вручну створити і видалити кластер у кожному інструменті.

### minikube

```bash
minikube start
kubectl get nodes
kubectl cluster-info
minikube status
minikube delete
```

### kind

```bash
kind create cluster --name asciiartify
kubectl get nodes
kubectl cluster-info
kind get clusters
kind delete cluster --name asciiartify
```

### k3d

```bash
k3d cluster create asciiartify
kubectl get nodes
kubectl cluster-info
k3d cluster list
k3d cluster delete asciiartify
```

Ця перевірка дозволяє підтвердити встановлення, створення kubeconfig/context, доступність API Server та повний lifecycle локального кластеру.

---

## 8. Demo: Hello World у k3d

### 8.1. Передумови

Потрібні:

- Docker-compatible container engine;
- `kubectl`;
- `k3d`;
- `curl`.

Перевірка:

```bash
docker version
kubectl version --client
k3d version
```

### 8.2. Створення multi-node кластеру

```bash
k3d cluster create asciiartify \
  --servers 1 \
  --agents 2 \
  -p "8080:80@loadbalancer" \
  --wait
```

Перевіримо кластер:

```bash
kubectl cluster-info
kubectl get nodes -o wide
k3d cluster list
```

Очікується один server node і два agent nodes.

### 8.3. Hello World manifest

Створимо `hello-world.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hello-world-html
data:
  index.html: |
    <!doctype html>
    <html>
      <head>
        <title>AsciiArtify PoC</title>
      </head>
      <body>
        <h1>Hello World from AsciiArtify!</h1>
      </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: html
              mountPath: /usr/share/nginx/html/index.html
              subPath: index.html
      volumes:
        - name: html
          configMap:
            name: hello-world-html
---
apiVersion: v1
kind: Service
metadata:
  name: hello-world
spec:
  selector:
    app: hello-world
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world
spec:
  ingressClassName: traefik
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hello-world
                port:
                  number: 80
```

Застосуємо manifest:

```bash
kubectl apply -f demo/hello-world.yaml
kubectl rollout status deployment/hello-world
kubectl get pods -o wide
kubectl get service
kubectl get ingress
```

### 8.4. Перевірка застосунку

```bash
curl http://localhost:8080
```

Очікуваний результат:

```html
<h1>Hello World from AsciiArtify!</h1>
```

Додатково можна перевірити replicas:

```bash
kubectl get deployment hello-world
kubectl get pods -l app=hello-world -o wide
```

### 8.5. Cleanup

```bash
kubectl delete -f demo/hello-world.yaml
k3d cluster delete asciiartify
```

---

## 9. Запис demo через asciinema

Запис бажано проводити у Linux або WSL.

Початок запису:

```bash
asciinema rec asciiartify-k3d.cast
```

Під час запису показати:

```bash
k3d version
kubectl version --client
k3d cluster create asciiartify --servers 1 --agents 2 -p "8080:80@loadbalancer" --wait
kubectl get nodes -o wide
kubectl apply -f demo/hello-world.yaml
kubectl rollout status deployment/hello-world
kubectl get pods,service,ingress
curl http://localhost:8080
k3d cluster delete asciiartify
```

Завершити запис `Ctrl+D`.

Після цього:

```bash
asciinema upload asciiartify-k3d.cast
```

Asciinema поверне URL типу:

```text
https://asciinema.org/a/XXXXXXXX
```

---

## 10. Вбудоване demo

Практичне demo записано після успішної перевірки PoC-кластера.

[![asciicast](https://asciinema.org/a/f1aMW5yAV3ZdbfHt.svg)](https://asciinema.org/a/f1aMW5yAV3ZdbfHt)

Пряме посилання на запис: https://asciinema.org/a/f1aMW5yAV3ZdbfHt

### Результат практичного тесту

Під час практичного тестування підтверджено:

- створення k3d-кластера з **1 server** та **2 agent** nodes;
- усі **3 Kubernetes nodes** перейшли у стан `Ready`;
- `kubectl` автоматично використовував context `k3d-asciiartify`;
- Deployment `hello-world` успішно розгорнув **2 replicas**;
- Service та Traefik Ingress створено успішно;
- застосунок доступний через k3d load balancer на `http://localhost:8080/`;
- HTTP-відповідь містила `Hello World from AsciiArtify!`.

Це підтверджує, що k3d забезпечує швидкий і відтворюваний локальний multi-node Kubernetes environment, достатній для PoC AsciiArtify.

---

## 11. Висновки

Для PoC стартапу **AsciiArtify** рекомендовано використовувати **k3d** як основний локальний Kubernetes environment.

**minikube** є найзручнішим для навчання та інтерактивної локальної роботи завдяки addons, dashboard та великій кількості drivers, але він дещо важчий і не настільки оптимізований під швидке створення ephemeral кластерів.

**kind** найкраще підходить для CI та тестування upstream Kubernetes. Він швидкий, reproducible і має сильну підтримку в Kubernetes ecosystem. Крім того, kind є найбільш привабливим із розглянутих варіантів для сценарію Podman-first.

**k3d** забезпечує найкращий баланс між швидкістю, простотою та функціональністю для PoC. Він дозволяє швидко створювати multi-node k3s кластери, має зручний load-balancer, registry integration та image import.

Фінальна рекомендація:

| Сценарій | Рекомендований інструмент |
|---|---|
| PoC AsciiArtify | **k3d** |
| Developer learning / dashboard / addons | **minikube** |
| CI/CD Kubernetes tests | **kind** |
| Podman-first environment | **kind + Podman** |
| Дуже швидкий lightweight multi-node cluster | **k3d** |

---

## 12. Джерела

- minikube documentation: https://minikube.sigs.k8s.io/docs/
- minikube drivers: https://minikube.sigs.k8s.io/docs/drivers/
- minikube Podman driver: https://minikube.sigs.k8s.io/docs/drivers/podman/
- kind documentation: https://kind.sigs.k8s.io/
- kind quick start: https://kind.sigs.k8s.io/docs/user/quick-start/
- kind rootless/Podman: https://kind.sigs.k8s.io/docs/user/rootless/
- k3d documentation: https://k3d.io/
- k3d GitHub: https://github.com/k3d-io/k3d
- k3d Podman documentation: https://k3d.io/stable/usage/advanced/podman/
- Docker Desktop licensing: https://docs.docker.com/subscription/desktop-license/
- Podman: https://podman.io/
