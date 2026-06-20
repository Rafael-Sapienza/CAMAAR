# Manual de Models e Relacionamentos no Ruby on Rails

Este guia foi projetado para servir como material de consulta rápida e profunda sobre o funcionamento das Models no Rails, focando nas convenções de nomes, nos dois métodos de configuração (manual e automático), na criação de relacionamentos (Um para Muitos e Muitos para Muitos) e nos métodos que a Model disponibiliza para os Controllers.

---

## 1. Convenções de Nomes e Estrutura de Pastas

A filosofia central do Rails é *Convention over Configuration* (Convenção sobre Configuração). Se você nomear seus arquivos nos lugares certos e com os nomes corretos, o Rails conectará tudo sem que você precise escrever linhas extras de configuração.

O Rails divide rigidamente o projeto entre o **Mundo do Banco de Dados** (tabelas literais e físicas) e o **Mundo do Ruby** (suas classes e objetos).

### Estrutura de Pastas OBRIGATÓRIA:
```text
seu_projeto/
├── app/
│   └── models/           # OBRIGATÓRIO: Onde ficam os arquivos Ruby das suas Models.
└── db/
    └── migrate/          # OBRIGATÓRIO: Onde ficam as alterações estruturais do banco.
```

### Regra de Ouro de Nomenclatura:

| Elemento | Mundo | Como escrever? | Número | Exemplo |
| :--- | :--- | :--- | :--- | :--- |
| **Model (Classe)** | Ruby | *CamelCase* (Sem underline) | **Singular** | `Professor`, `MedicalDepartment` |
| **Arquivo do Model** | Ruby | *snake_case* (`.rb`) | **Singular** | `professor.rb`, `medical_department.rb` |
| **Tabela no Banco** | Banco | *snake_case* (Letras minúsculas) | **Plural** | `professors`, `medical_departments` |
| **Chave Estrangeira** | Banco | `nome_da_tabela_no_singular_id` | **Singular** | `department_id`, `professor_id` |

---

## 2. Os Dois Métodos para Configurar uma Model

O Rails oferece duas abordagens para construir suas tabelas e Models: o método automático (usando geradores no terminal) e o método 100% manual. Ambos geram exatamente o mesmo resultado final.

### Método A: O Modo Automático (Atalho por Terminal)
Este método é o mais utilizado no dia a dia porque poupa tempo, gerando a Model e a sua respectiva Migration em um único comando.

* **Como escrever no terminal:**
```bash
rails generate model Professor name:string department:references
```

* **O que o Rails faz por baixo dos panos:**
  1. Cria um arquivo de migração em `db/migrate/..._create_professors.rb` já preenchido com os campos `name` e a chave estrangeira `department_id`.
  2. Cria o arquivo da classe em `app/models/professor.rb` já contendo a linha de associação `belongs_to :department`.

---

### Método B: O Modo Manual (Construindo tudo no VS Code)
Útil para entender a arquitetura por trás do framework ou quando você quer total controle desde o primeiro segundo.

#### Passo 1: Gerar uma migration em branco
Para não errar o carimbo de data/hora que o Rails exige nos arquivos de banco, gere apenas a migration vazia no terminal:
```bash
rails generate migration CreateProfessors
```

#### Passo 2: Codificar a Migration na mão
Abra o arquivo gerado em `db/migrate/` e escreva os tipos de colunas e as referências:
```ruby
class CreateProfessors < ActiveRecord::Migration[7.1]
  def change
    create_table :professors do |t|
      t.string :name
      
      # Define manualmente a criação da FK 'department_id' apontando para a tabela 'departments'
      t.references :department, null: false, foreign_key: true

      t.timestamps
    end
  end
end
```
No terminal, aplique a mudança para criar a tabela física:
```bash
rails db:migrate
```

#### Passo 3: Criar o arquivo da Model manualmente no VS Code
1. Vá até a pasta `app/models/`.
2. Crie um novo arquivo chamado exatamente `professor.rb`.
3. Digite o escopo da classe herdando de `ApplicationRecord` e configure as associações:
```ruby
# app/models/professor.rb
class Professor < ApplicationRecord
  belongs_to :department
end
```

---

## 3. Relacionamento de Um para Muitos (One-to-Many)

Ocorre quando um registro de uma tabela "A" possui vários registros em uma tabela "B", mas o registro de "B" pertence a apenas um de "A".
* **Exemplo Clássico:** Um Departamento (`Department`) possui vários Professores (`Professor`), mas cada professor trabalha em apenas um departamento.

### A Migration (Banco de Dados)
A regra fundamental do banco de dados relacional dita: **A Chave Estrangeira (FK) fica SEMPRE no lado "Muitos" da relação.** Portanto, a tabela de professores deve guardar a coluna `department_id`.

```ruby
# db/migrate/20260613000000_create_professors.rb
class CreateProfessors < ActiveRecord::Migration[7.1]
  def change
    create_table :professors do |t|
      t.string :name
      t.references :department, null: false, foreign_key: true
      t.timestamps
    end
  end
end
```

### Configuração das Models (Ruby)
No lado **Um** (`Department`), usamos a macro `has_many` passando o nome da outra tabela no **plural**:
```ruby
# app/models/department.rb
class Department < ApplicationRecord
  has_many :professors
end
```

No lado **Muitos** (`Professor`), usamos a macro `belongs_to` passando o nome do relacionamento no **singular**:
```ruby
# app/models/professor.rb
class Professor < ApplicationRecord
  belongs_to :department
end
```

---

## 4. Relacionamento de Muitos para Muitos (Many-to-Many)

Ocorre quando múltiplos registros de uma tabela se conectam a múltiplos registros de outra. Bancos de dados relacionais não conseguem fazer essa ligação de forma direta; **é obrigatório criar uma terceira tabela relacional (tabela de junção ou pivô)** para unir os IDs.

* **Exemplo Real:** Um Médico (`Doctor`) atende muitos Pacientes (`Patient`), e um Paciente se consulta com muitos Médicos. A tabela do meio será a Consulta (`Appointment`).



### Configurando as Migrations (As Três Tabelas Físicas)

Você precisará criar a tabela de Médicos, a tabela de Pacientes e, por fim, a tabela de Consultas contendo as duas Chaves Estrangeiras.

```ruby
# 1. Tabela de Médicos
class CreateDoctors < ActiveRecord::Migration[7.1]
  def change
    create_table :doctors do |t|
      t.string :name
      t.string :specialty
      t.timestamps
    end
  end
end

# 2. Tabela de Pacientes
class CreatePatients < ActiveRecord::Migration[7.1]
  def change
    create_table :patients do |t|
      t.string :name
      t.timestamps
    end
  end
end

# 3. Tabela Relacional / Junção (Consultas)
class CreateAppointments < ActiveRecord::Migration[7.1]
  def change
    create_table :appointments do |t|
      # Guarda a FK doctor_id e a FK patient_id
      t.references :doctor, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.datetime :appointment_date

      t.timestamps
    end
  end
end
```

### Configuração das Models com `has_many :through`

Para dar à sua aplicação o poder de coletar a lista de pacientes diretamente a partir de um médico (e vice-versa), usamos a macro `has_many :through`. Ela avisa ao Rails que ele deve passar pela tabela do meio para alcançar o destino final.

```ruby
# app/models/doctor.rb
class Doctor < ApplicationRecord
  # 1. Conecta-se diretamente com a tabela relacional
  has_many :appointments
  
  # 2. Conecta-se aos pacientes ATRAVÉS das consultas
  has_many :patients, through: :appointments
end
```

```ruby
# app/models/patient.rb
class Patient < ApplicationRecord
  # 1. Conecta-se diretamente com a tabela relacional
  has_many :appointments
  
  # 2. Conecta-se aos médicos ATRAVÉS das consultas
  has_many :doctors, through: :appointments
end
```

```ruby
# app/models/appointment.rb
class Appointment < ApplicationRecord
  # A tabela de junção pertence aos dois lados individualmente
  belongs_to :doctor
  belongs_to :patient
end
```

---

## 5. Métodos que a Model oferece ao Controller (CRUD)

Quando as suas Models e relacionamentos estão configurados, o Rails disponibiliza uma API completa de métodos em Ruby para você gerenciar os dados dentro dos seus Controllers.

### 1. Criar dados (Create)

* **`new`**: Instancia um objeto na memória RAM do computador, mas **não salva** no banco de dados ainda. Requer o método `.save` posterior.
```ruby
# No Controller:
@product = Product.new(name: "Mouse Sem Fio", price: 89.90)
if @product.save
  # Salvo com sucesso no banco
end
```

* **`create`**: Instancia o objeto e tenta salvá-lo imediatamente no banco. Retorna o objeto independente de ter funcionado ou falhado.
```ruby
@product = Product.create(name: "Teclado", price: 150.00)
```

* **`create!`**: Igual ao `create`, mas se houver alguma falha de validação (ex: preço em branco), ele interrompe a execução e **lança uma exceção/erro na tela** (`ActiveRecord::RecordInvalid`). Muito útil para debugar ou em seeds.
```ruby
@product = Product.create!(name: "Teclado", price: 150.00)
```

### 2. Ler e Buscar dados (Read)

* **`all`**: Traz todos os registros da tabela em formato de coleção.
```ruby
@professors = Professor.all
```

* **`find`**: Busca um registro diretamente pelo seu número de ID. Se o ID não existir, ele quebra a aplicação lançando um erro `RecordNotFound`.
```ruby
@doctor = Doctor.find(2) # Busca o médico com id = 2
```

* **`find_by`**: Busca por uma coluna customizada. Se não encontrar nada, ele não quebra o sistema; apenas retorna `nil` (nulo).
```ruby
@patient = Patient.find_by(name: "Ana Silva")
```

* **`where`**: Filtra múltiplos registros com base em condições estruturadas.
```ruby
# Busca todos os médicos da especialidade Pediatria
@pediatras = Doctor.where(specialty: "Pediatria")
```

### 3. Atualizar dados (Update)

* **`update`**: Atualiza os atributos passados e salva no banco imediatamente, rodando as validações. Retorna `true` se funcionar e `false` se falhar.
```ruby
@product = Product.find(1)
@product.update(price: 79.90)
```

### 4. Deletar dados (Destroy)

* **`destroy`**: Remove o registro do banco de dados de forma definitiva e ativa os gatilhos de segurança das Models.
```ruby
@professor = Professor.find(5)
@professor.destroy # Remove o professor de ID 5 do banco
```

---

## 6. Como os Relacionamentos funcionam na Prática (Exemplos de Código)

Graças às configurações de associações que fizemos nas Models, veja como você pode manipular e buscar dados de forma extremamente simples no terminal (`rails console`) ou dentro dos seus Controllers.

### Cenário A: Praticando o relacionamento de Um para Muitos (One-to-Many)
*Contexto: Um departamento tem muitos professores.*

```ruby
# 1. Criando o registro Pai (O Departamento)
depto_exatas = Department.create!(name: "Departamento de Exatas")

# 2. Criando os registros Filhos (Professores) já vinculados ao Pai
# Passamos o objeto 'depto_exatas' diretamente no atributo 'department'
Professor.create!(name: "Alan Turing", department: depto_exatas)
Professor.create!(name: "Ada Lovelace", department: depto_exatas)

# 3. Fazendo buscas a partir do Pai (Department)
depto_exatas.professors.count # Retorna: 2
depto_exatas.professors       # Retorna uma lista contendo os objetos de [Alan Turing, Ada Lovelace]

# 4. Fazendo a busca a partir do Filho (Professor)
professor = Professor.find_by(name: "Alan Turing")
professor.department          # Retorna o objeto completo do "Departamento de Exatas"
professor.department.name     # Retorna a string: "Departamento de Exatas"
```

---

### Cenário B: Praticando o relacionamento de Muitos para Muitos (Many-to-Many)
*Contexto: Médicos e Pacientes conectados através de Consultas (Appointments).*

```ruby
# 1. Criando os registros base das pontas
medico = Doctor.create!(name: "Dr. House", specialty: "Infectologia")
paciente_joao = Patient.create!(name: "João Silva")
paciente_maria = Patient.create!(name: "Maria Souza")

# 2. Criando o relacionamento salvando registros na tabela de junção (Appointment)
# O Rails aceita que passemos os objetos inteiros 'medico' e 'paciente' como argumentos
Appointment.create!(doctor: medico, patient: paciente_joao, appointment_date: DateTime.now)
Appointment.create!(doctor: medico, patient: paciente_maria, appointment_date: DateTime.now)

# 3. Fazendo buscas inteligentes (A mágica do has_many :through)
medico.patients.count # Retorna: 2
medico.patients       # Retorna uma lista contendo os objetos de [João Silva, Maria Souza]

# 4. O caminho inverso também funciona de forma 100% automática
paciente_joao.doctors # Retorna uma lista contendo o objeto de [Dr. House]
```