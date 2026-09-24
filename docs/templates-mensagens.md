# Templates de Mensagens — TechReserve FATEC Franco da Rocha

Este documento contém os modelos homologados para notificação transacional via **WhatsApp Meta Cloud API** e **E-mails Transacionais**.

---

## 1. Templates de WhatsApp (Meta Cloud API)

### 1.1 `reserva_confirmada`
- **Categoria:** TRANSACTIONAL
- **Idioma:** pt_BR
- **Corpo:**
> Olá {{1}}, sua reserva para a sala *{{2}}* na FATEC Franco da Rocha foi confirmada para o dia *{{3}}* das *{{4}}* às *{{5}}*. Lembre-se de realizar o check-in no sistema até 15 minutos após o início da aula.

### 1.2 `reserva_cancelada`
- **Categoria:** TRANSACTIONAL
- **Idioma:** pt_BR
- **Corpo:**
> Olá {{1}}, sua reserva para a sala *{{2}}* no dia *{{3}}* às *{{4}}* foi cancelada com sucesso. A sala está novamente livre para a comunidade docente.

---

## 2. Templates de E-mail (HTML)

### 2.1 E-mail de Confirmação de Reserva
```html
<div style="background:#131315; color:#e5e1e4; font-family:sans-serif; padding:24px; border:1px solid #574240;">
  <h2 style="color:#ffb3ad;">TechReserve — FATEC Franco da Rocha</h2>
  <p>Sua reserva foi confirmada com sucesso!</p>
  <ul>
    <li><strong>Sala:</strong> {{room_name}}</li>
    <li><strong>Data:</strong> {{date}}</li>
    <li><strong>Horário:</strong> {{start_time}} - {{end_time}}</li>
  </ul>
</div>
```
