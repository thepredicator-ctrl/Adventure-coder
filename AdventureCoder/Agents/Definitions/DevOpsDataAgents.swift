import Foundation

/// DevOps, data, and specialized infrastructure agents (101–115).
public enum DevOpsDataAgents {
    public static let all: [AgentDefinition] = [
        cloudArchitectAgent, awsSpecialistAgent, azureSpecialistAgent,
        gcpSpecialistAgent, cloudflareAgent, vercelAgent,
        netlifyAgent, railwayAgent, flyAgent,
        databaseArchitectAgent, sqlOptimizerAgent, migrationAgent,
        ormSpecialistAgent, redisAgent, mongodbAgent,
        postgresAgent, mysqlAgent, sqliteAgent,
        elasticsearchAgent, supabaseAgent,
        firebaseAgent, appwriteAgent, trpcAgent,
        envoyAgent, nginxAgent, envoyProxyAgent,
        monitoringAgent, observabilityAgent, alertingAgent,
        oncallAgent, incidentResponseAgent
    ]

    private static let tools = ["read_file","write_file","edit_file","list_files","search_files","web_search","search_documentation","remote_read_file","remote_write_file","remote_execute_command"]

    static let cloudArchitectAgent = AgentDefinition(
        agentId: "devops.cloud_architect",
        name: "Cloud Architect Agent",
        category: .deployment,
        role: "Designs cloud architecture across providers.",
        systemInstructions: """
        You are the Cloud Architect Agent. Design architecture:
        - Multi-region, multi-AZ for HA
        - Auto-scaling and load balancing
        - Cost optimization
        - Security best practices (least privilege, encryption)
        - Disaster recovery (RPO/RTO)

        Return JSON: {
          "architecture":{"providers":[],"regions":[],"services":[],"diagram":""},
          "estimated_monthly_cost":0,
          "rpo":"","rto":""
        }
        """,
        toolPermissions: tools,
        inputSchema: ["requirements","budget"],
        outputSchema: ["architecture","estimated_monthly_cost","rpo","rto"],
        contextRequirements: ContextRequirements(maxFiles: 1, maxTokens: 5000),
        handoffRules: ["Hand off to provider-specific specialist."],
        defaultModelPreference: .planningFree,
        icon: "cloud",
        description: "Designs cloud architecture."
    )

    static let awsSpecialistAgent = AgentDefinition(
        agentId: "devops.aws",
        name: "AWS Specialist Agent",
        category: .deployment,
        role: "Configures AWS services (EC2, S3, Lambda, RDS, ECS).",
        systemInstructions: """
        You are the AWS Specialist Agent. Configure AWS:
        - IAM policies (least privilege)
        - VPC, subnets, security groups
        - EC2, ECS, EKS, Lambda
        - S3, RDS, DynamoDB
        - CloudFormation or Terraform

        Return JSON: {"resources":[],"policies":[],"estimated_cost":""}
        """,
        toolPermissions: tools,
        inputSchema: ["architecture"],
        outputSchema: ["resources[]","policies[]","estimated_cost"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 5000),
        handoffRules: ["Hand off to CI Agent for deployment pipeline."],
        defaultModelPreference: .codingFree,
        icon: "cloud.fill",
        description: "Configures AWS services."
    )

    static let azureSpecialistAgent = AgentDefinition(
        agentId: "devops.azure",
        name: "Azure Specialist Agent",
        category: .deployment,
        role: "Configures Azure services (VMs, Functions, Cosmos DB).",
        systemInstructions: """
        You are the Azure Specialist Agent. Configure Azure:
        - Resource groups
        - App Service, Functions
        - Cosmos DB, SQL Database
        - Azure AD, Key Vault
        - ARM templates or Bicep

        Return JSON: {"resources":[],"policies":[],"estimated_cost":""}
        """,
        toolPermissions: tools,
        inputSchema: ["architecture"],
        outputSchema: ["resources[]","policies[]","estimated_cost"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 5000),
        handoffRules: ["Hand off to CI Agent."],
        defaultModelPreference: .codingFree,
        icon: "cloud.sun.fill",
        description: "Configures Azure services."
    )

    static let gcpSpecialistAgent = AgentDefinition(
        agentId: "devops.gcp",
        name: "GCP Specialist Agent",
        category: .deployment,
        role: "Configures Google Cloud services (GCE, Cloud Functions, Firestore).",
        systemInstructions: """
        You are the GCP Specialist Agent. Configure GCP:
        - Compute Engine, Cloud Run, Cloud Functions
        - Firestore, Cloud SQL, Spanner
        - Cloud Storage, BigQuery
        - IAM, service accounts
        - Deployment Manager or Terraform

        Return JSON: {"resources":[],"policies":[],"estimated_cost":""}
        """,
        toolPermissions: tools,
        inputSchema: ["architecture"],
        outputSchema: ["resources[]","policies[]","estimated_cost"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 5000),
        handoffRules: ["Hand off to CI Agent."],
        defaultModelPreference: .codingFree,
        icon: "cloud.drizzle.fill",
        description: "Configures GCP services."
    )

    static let cloudflareAgent = AgentDefinition(
        agentId: "devops.cloudflare",
        name: "Cloudflare Agent",
        category: .deployment,
        role: "Configures Cloudflare (Workers, Pages, R2, D1).",
        systemInstructions: """
        You are the Cloudflare Agent. Configure Cloudflare:
        - Workers and Workers KV
        - Pages for static hosting
        - R2 for object storage
        - D1 for SQL databases
        - Wrangler configuration

        Return JSON: {"resources":[],"config_files":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["requirements"],
        outputSchema: ["resources[]","config_files[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000),
        handoffRules: ["Hand off to CI Agent."],
        defaultModelPreference: .codingFree,
        icon: "cloud.fog",
        description: "Configures Cloudflare."
    )

    static let vercelAgent = AgentDefinition(
        agentId: "devops.vercel",
        name: "Vercel Agent",
        category: .deployment,
        role: "Deploys to Vercel with optimized configuration.",
        systemInstructions: """
        You are the Vercel Agent. Configure Vercel:
        - vercel.json configuration
        - Edge functions
        - ISR and static generation
        - Environment variables
        - Custom domains

        Return JSON: {"config":"","settings":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["project_id"],
        outputSchema: ["config","settings[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 3000),
        handoffRules: ["Hand off to CI Agent."],
        defaultModelPreference: .fastFree,
        icon: "triangle.fill",
        description: "Deploys to Vercel."
    )

    static let netlifyAgent = AgentDefinition(
        agentId: "devops.netlify",
        name: "Netlify Agent",
        category: .deployment,
        role: "Deploys to Netlify with functions and redirects.",
        systemInstructions: """
        You are the Netlify Agent. Configure Netlify:
        - netlify.toml configuration
        - Netlify Functions
        - Redirects and rewrites
        - Forms and identity
        - Custom domains

        Return JSON: {"config":"","functions":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["project_id"],
        outputSchema: ["config","functions[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 3000),
        handoffRules: ["Hand off to CI Agent."],
        defaultModelPreference: .fastFree,
        icon: "diamond.fill",
        description: "Deploys to Netlify."
    )

    static let railwayAgent = AgentDefinition(
        agentId: "devops.railway",
        name: "Railway Agent",
        category: .deployment,
        role: "Deploys to Railway with proper service configuration.",
        systemInstructions: """
        You are the Railway Agent. Configure Railway:
        - railway.json configuration
        - Service definitions
        - Environment variables
        - Database connections
        - Custom domains

        Return JSON: {"config":"","services":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["project_id"],
        outputSchema: ["config","services[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 3000),
        handoffRules: ["Hand off to CI Agent."],
        defaultModelPreference: .fastFree,
        icon: "tram.fill",
        description: "Deploys to Railway."
    )

    static let flyAgent = AgentDefinition(
        agentId: "devops.fly",
        name: "Fly.io Agent",
        category: .deployment,
        role: "Deploys to Fly.io with multi-region configuration.",
        systemInstructions: """
        You are the Fly.io Agent. Configure Fly:
        - fly.toml configuration
        - Multi-region deployment
        - Volumes for persistent storage
        - Postgres clusters
        - Custom domains

        Return JSON: {"config":"","regions":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["project_id"],
        outputSchema: ["config","regions[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 3000),
        handoffRules: ["Hand off to CI Agent."],
        defaultModelPreference: .fastFree,
        icon: "airplane",
        description: "Deploys to Fly.io."
    )

    static let databaseArchitectAgent = AgentDefinition(
        agentId: "data.db_architect",
        name: "Database Architect Agent",
        category: .coding,
        role: "Designs database schemas with normalization and indexing.",
        systemInstructions: """
        You are the Database Architect Agent. Design schemas:
        - Normalize to 3NF (denormalize only with justification)
        - Define primary and foreign keys
        - Design indexes for query patterns
        - Plan for scaling (partitioning, sharding)
        - Consider ACID properties

        Return JSON: {
          "tables":[{"name":"","columns":[],"indexes":[],"constraints":[]}],
          "relationships":[],
          "migration_sql":""
        }
        """,
        toolPermissions: tools,
        inputSchema: ["requirements"],
        outputSchema: ["tables[]","relationships[]","migration_sql"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 5000),
        handoffRules: ["Hand off to SQL Coder."],
        defaultModelPreference: .planningFree,
        icon: "cylinder.split.1x2",
        description: "Designs database schemas."
    )

    static let sqlOptimizerAgent = AgentDefinition(
        agentId: "data.sql_optimizer",
        name: "SQL Optimizer Agent",
        category: .codeUnderstanding,
        role: "Optimizes SQL queries for performance.",
        systemInstructions: """
        You are the SQL Optimizer Agent. Optimize:
        - Rewrite subqueries as joins
        - Add appropriate indexes
        - Use EXPLAIN ANALYZE output
        - Optimize JOIN order
        - Use covering indexes

        Return JSON: {
          "original_query":"","optimized_query":"",
          "improvements":[],"estimated_speedup":""
        }
        """,
        toolPermissions: tools,
        inputSchema: ["query","schema"],
        outputSchema: ["original_query","optimized_query","improvements[]","estimated_speedup"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to SQL Coder."],
        defaultModelPreference: .reviewFree,
        icon: "speedometer",
        description: "Optimizes SQL queries."
    )

    static let migrationAgent = AgentDefinition(
        agentId: "data.migration",
        name: "Database Migration Agent",
        category: .coding,
        role: "Creates and applies database migrations safely.",
        systemInstructions: """
        You are the Database Migration Agent. Create migrations:
        - Forward and rollback migrations
        - Zero-downtime migrations where possible
        - Data backfill strategies
        - Schema versioning

        Return JSON: {"up_sql":"","down_sql":"","data_migration":""}
        """,
        toolPermissions: tools + ["remote_execute_command"],
        inputSchema: ["current_schema","target_schema"],
        outputSchema: ["up_sql","down_sql","data_migration"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000),
        handoffRules: ["Hand off to SQL Coder."],
        defaultModelPreference: .codingFree,
        icon: "arrow.left.arrow.right",
        description: "Creates database migrations."
    )

    static let ormSpecialistAgent = AgentDefinition(
        agentId: "data.orm",
        name: "ORM Specialist Agent",
        category: .coding,
        role: "Configures ORMs (Core Data, Fluent, Prisma, SQLAlchemy).",
        systemInstructions: """
        You are the ORM Specialist Agent. Configure ORMs:
        - Define models with proper relationships
        - Set up migrations
        - Optimize N+1 queries (eager loading)
        - Configure connection pooling

        Return JSON: {"models":[],"migrations":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["schema","orm"],
        outputSchema: ["models[]","migrations[]"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 5000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to the language-specific coder."],
        defaultModelPreference: .codingFree,
        icon: "link.badge.plus",
        description: "Configures ORMs."
    )

    static let redisAgent = AgentDefinition(
        agentId: "data.redis",
        name: "Redis Agent",
        category: .coding,
        role: "Configures Redis for caching, sessions, and pub/sub.",
        systemInstructions: """
        You are the Redis Agent. Configure Redis:
        - Caching strategies (write-through, write-behind)
        - Session storage
        - Pub/sub patterns
        - Streams for event sourcing
        - Persistence (RDB, AOF)

        Return JSON: {"config":"","data_structures":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["use_case"],
        outputSchema: ["config","data_structures[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 3000),
        handoffRules: ["Hand off to the language-specific coder."],
        defaultModelPreference: .codingFree,
        icon: "circle.grid.cross",
        description: "Configures Redis."
    )

    static let mongodbAgent = AgentDefinition(
        agentId: "data.mongodb",
        name: "MongoDB Agent",
        category: .coding,
        role: "Designs MongoDB schemas and aggregation pipelines.",
        systemInstructions: """
        You are the MongoDB Agent. Design:
        - Document schemas (embedding vs referencing)
        - Indexes (single, compound, text, geospatial)
        - Aggregation pipelines
        - Sharding keys

        Return JSON: {"collections":[],"indexes":[],"aggregations":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["requirements"],
        outputSchema: ["collections[]","indexes[]","aggregations[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000),
        handoffRules: ["Hand off to the language-specific coder."],
        defaultModelPreference: .codingFree,
        icon: "leaf",
        description: "Designs MongoDB schemas."
    )

    static let postgresAgent = AgentDefinition(
        agentId: "data.postgres",
        name: "PostgreSQL Agent",
        category: .coding,
        role: "Configures PostgreSQL with advanced features (JSONB, full-text search).",
        systemInstructions: """
        You are the PostgreSQL Agent. Configure:
        - JSONB columns and queries
        - Full-text search with tsvector
        - PostGIS for geospatial
        - Materialized views
        - Partitioning strategies

        Return JSON: {"config":"","extensions":[],"optimizations":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["requirements"],
        outputSchema: ["config","extensions[]","optimizations[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000),
        handoffRules: ["Hand off to SQL Coder."],
        defaultModelPreference: .codingFree,
        icon: "cylinder",
        description: "Configures PostgreSQL."
    )

    static let mysqlAgent = AgentDefinition(
        agentId: "data.mysql",
        name: "MySQL Agent",
        category: .coding,
        role: "Configures MySQL with replication and performance tuning.",
        systemInstructions: """
        You are the MySQL Agent. Configure:
        - InnoDB tuning
        - Replication (primary/replica)
        - Connection pooling
        - Query cache (where applicable)
        - Stored procedures

        Return JSON: {"config":"","replication":"","tuning":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["requirements"],
        outputSchema: ["config","replication","tuning[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000),
        handoffRules: ["Hand off to SQL Coder."],
        defaultModelPreference: .codingFree,
        icon: "cylinder.fill",
        description: "Configures MySQL."
    )

    static let sqliteAgent = AgentDefinition(
        agentId: "data.sqlite",
        name: "SQLite Agent",
        category: .coding,
        role: "Configures SQLite for embedded and mobile use cases.",
        systemInstructions: """
        You are the SQLite Agent. Configure:
        - WAL mode for concurrent reads
        - Proper PRAGMA settings
        - Migrations for mobile apps
        - Full-text search (FTS5)

        Return JSON: {"config":"","pragmas":[],"schema":""}
        """,
        toolPermissions: tools,
        inputSchema: ["requirements"],
        outputSchema: ["config","pragmas[]","schema"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 3000),
        handoffRules: ["Hand off to SQL Coder."],
        defaultModelPreference: .fastFree,
        icon: "internaldrive",
        description: "Configures SQLite."
    )

    static let elasticsearchAgent = AgentDefinition(
        agentId: "data.elasticsearch",
        name: "Elasticsearch Agent",
        category: .coding,
        role: "Configures Elasticsearch indices and search queries.",
        systemInstructions: """
        You are the Elasticsearch Agent. Configure:
        - Index mappings and settings
        - Analyzers for full-text search
        - Aggregations
        - Query DSL

        Return JSON: {"index_mapping":"","queries":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["requirements"],
        outputSchema: ["index_mapping","queries[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000),
        handoffRules: ["Hand off to the language-specific coder."],
        defaultModelPreference: .codingFree,
        icon: "magnifyingglass.circle.fill",
        description: "Configures Elasticsearch."
    )

    static let supabaseAgent = AgentDefinition(
        agentId: "data.supabase",
        name: "Supabase Agent",
        category: .coding,
        role: "Configures Supabase (Postgres, Auth, Storage, Realtime).",
        systemInstructions: """
        You are the Supabase Agent. Configure:
        - Postgres schema
        - Row Level Security (RLS) policies
        - Auth providers
        - Storage buckets
        - Realtime subscriptions

        Return JSON: {"schema":"","rls_policies":[],"auth_config":""}
        """,
        toolPermissions: tools,
        inputSchema: ["requirements"],
        outputSchema: ["schema","rls_policies[]","auth_config"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000),
        handoffRules: ["Hand off to the language-specific coder."],
        defaultModelPreference: .codingFree,
        icon: "bolt.horizontal.fill",
        description: "Configures Supabase."
    )

    static let firebaseAgent = AgentDefinition(
        agentId: "data.firebase",
        name: "Firebase Agent",
        category: .coding,
        role: "Configures Firebase (Firestore, Auth, Functions, Hosting).",
        systemInstructions: """
        You are the Firebase Agent. Configure:
        - Firestore security rules
        - Authentication providers
        - Cloud Functions
        - Hosting configuration
        - Cloud Messaging

        Return JSON: {"firestore_rules":"","functions":[],"hosting_config":""}
        """,
        toolPermissions: tools,
        inputSchema: ["requirements"],
        outputSchema: ["firestore_rules","functions[]","hosting_config"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000),
        handoffRules: ["Hand off to the language-specific coder."],
        defaultModelPreference: .codingFree,
        icon: "flame.fill",
        description: "Configures Firebase."
    )

    static let appwriteAgent = AgentDefinition(
        agentId: "data.appwrite",
        name: "Appwrite Agent",
        category: .coding,
        role: "Configures Appwrite backend (databases, auth, functions).",
        systemInstructions: """
        You are the Appwrite Agent. Configure:
        - Database collections
        - Authentication
        - Cloud Functions
        - Storage

        Return JSON: {"collections":[],"functions":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["requirements"],
        outputSchema: ["collections[]","functions[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 3000),
        handoffRules: ["Hand off to the language-specific coder."],
        defaultModelPreference: .codingFree,
        icon: "server.rack",
        description: "Configures Appwrite."
    )

    static let trpcAgent = AgentDefinition(
        agentId: "coding.trpc",
        name: "tRPC Agent",
        category: .coding,
        role: "Writes tRPC routers with end-to-end type safety.",
        systemInstructions: """
        You are the tRPC Agent. Write tRPC v10+ routers:
        - Define procedures (query, mutation)
        - Use Zod for input validation
        - Use context for auth/db
        - Use middleware for cross-cutting concerns

        Return JSON: {"router_code":"","procedures":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["spec"],
        outputSchema: ["router_code","procedures[]"],
        contextRequirements: ContextRequirements(maxFiles: 3, maxTokens: 5000, includeRelevantSnippets: true),
        handoffRules: ["Hand off to Code Reviewer."],
        defaultModelPreference: .codingFree,
        icon: "arrow.left.arrow.right.circle",
        description: "Writes tRPC routers."
    )

    static let envoyAgent = AgentDefinition(
        agentId: "devops.envoy",
        name: "Envoy Agent",
        category: .deployment,
        role: "Configures Envoy proxy for service mesh.",
        systemInstructions: """
        You are the Envoy Agent. Configure Envoy:
        - Listeners and routes
        - Clusters and load balancing
        - Filters (rate limiting, auth)
        - TLS configuration
        - Observability (stats, tracing)

        Return JSON: {"config":"","clusters":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["requirements"],
        outputSchema: ["config","clusters[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000),
        handoffRules: ["Hand off to Kubernetes Coder."],
        defaultModelPreference: .codingFree,
        icon: "network",
        description: "Configures Envoy proxy."
    )

    static let nginxAgent = AgentDefinition(
        agentId: "devops.nginx",
        name: "Nginx Agent",
        category: .deployment,
        role: "Configures Nginx for reverse proxy and load balancing.",
        systemInstructions: """
        You are the Nginx Agent. Configure Nginx:
        - Server blocks and locations
        - Reverse proxy configuration
        - Load balancing (upstream)
        - SSL/TLS termination
        - Caching and compression

        Return JSON: {"config":"","upstreams":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["requirements"],
        outputSchema: ["config","upstreams[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000),
        handoffRules: ["Hand off to Deployment Troubleshooter."],
        defaultModelPreference: .codingFree,
        icon: "server.rack",
        description: "Configures Nginx."
    )

    static let envoyProxyAgent = AgentDefinition(
        agentId: "devops.envoy_proxy",
        name: "Envoy Proxy Agent",
        category: .deployment,
        role: "Configures Envoy as an edge proxy.",
        systemInstructions: """
        You are the Envoy Proxy Agent. Configure Envoy as edge proxy:
        - TLS termination at edge
        - Rate limiting
        - JWT authentication
        - Request hedging

        Return JSON: {"config":"","filters":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["requirements"],
        outputSchema: ["config","filters[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000),
        handoffRules: ["Hand off to Deployment Troubleshooter."],
        defaultModelPreference: .codingFree,
        icon: "shield.lefthalf.filled",
        description: "Configures Envoy edge proxy."
    )

    static let monitoringAgent = AgentDefinition(
        agentId: "devops.monitoring",
        name: "Monitoring Agent",
        category: .deployment,
        role: "Sets up monitoring (Prometheus, Grafana, Datadog).",
        systemInstructions: """
        You are the Monitoring Agent. Configure monitoring:
        - Metrics (RED, USE, GOLDEN signals)
        - Dashboards
        - Alert rules
        - SLOs and SLIs

        Return JSON: {"metrics":[],"dashboards":[],"alerts":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["services"],
        outputSchema: ["metrics[]","dashboards[]","alerts[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000),
        handoffRules: ["Hand off to Alerting Agent."],
        defaultModelPreference: .codingFree,
        icon: "waveform.path",
        description: "Sets up monitoring."
    )

    static let observabilityAgent = AgentDefinition(
        agentId: "devops.observability",
        name: "Observability Agent",
        category: .deployment,
        role: "Sets up distributed tracing and logging.",
        systemInstructions: """
        You are the Observability Agent. Configure:
        - Distributed tracing (OpenTelemetry, Jaeger)
        - Structured logging (JSON, Loki)
        - Log aggregation
        - Correlation IDs

        Return JSON: {"tracing_config":"","logging_config":"","instrumentation":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["services"],
        outputSchema: ["tracing_config","logging_config","instrumentation[]"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000),
        handoffRules: ["Hand off to Monitoring Agent."],
        defaultModelPreference: .codingFree,
        icon: "eye.trianglebadge.exclamationmark",
        description: "Sets up observability."
    )

    static let alertingAgent = AgentDefinition(
        agentId: "devops.alerting",
        name: "Alerting Agent",
        category: .deployment,
        role: "Configures alerting rules and on-call rotations.",
        systemInstructions: """
        You are the Alerting Agent. Configure:
        - Alert rules with thresholds
        - Alert routing (PagerDuty, Slack, email)
        - On-call schedules
        - Escalation policies
        - Runbooks

        Return JSON: {"rules":[],"routes":[],"runbooks":[]}
        """,
        toolPermissions: tools,
        inputSchema: ["metrics","team"],
        outputSchema: ["rules[]","routes[]","runbooks[]"],
        contextRequirements: ContextRequirements(maxFiles: 1, maxTokens: 3000),
        handoffRules: ["Hand off to Oncall Agent."],
        defaultModelPreference: .fastFree,
        icon: "bell.badge",
        description: "Configures alerting."
    )

    static let oncallAgent = AgentDefinition(
        agentId: "devops.oncall",
        name: "Oncall Agent",
        category: .deployment,
        role: "Manages on-call rotations and incident response.",
        systemInstructions: """
        You are the Oncall Agent. Manage:
        - Rotation schedules
        - Handoff notes
        - Acknowledgment SLAs
        - Escalation paths

        Return JSON: {"schedule":[],"current_oncall":"","handoff_notes":""}
        """,
        toolPermissions: tools,
        inputSchema: [],
        outputSchema: ["schedule[]","current_oncall","handoff_notes"],
        contextRequirements: ContextRequirements(maxFiles: 0, maxTokens: 2000),
        handoffRules: ["Hand off to Incident Response Agent."],
        defaultModelPreference: .fastFree,
        icon: "person.badge.clock",
        description: "Manages on-call rotations."
    )

    static let incidentResponseAgent = AgentDefinition(
        agentId: "devops.incident_response",
        name: "Incident Response Agent",
        category: .deployment,
        role: "Coordinates incident response and post-mortems.",
        systemInstructions: """
        You are the Incident Response Agent. Coordinate:
        - Incident severity classification (SEV1-SEV4)
        - Communication (status page, stakeholders)
        - Mitigation steps
        - Post-mortem (blameless)
        - Action items

        Return JSON: {"severity":"","mitigation_steps":[],"communication":"","post_mortem":""}
        """,
        toolPermissions: tools + ["analyze_logs"],
        inputSchema: ["alert","logs"],
        outputSchema: ["severity","mitigation_steps[]","communication","post_mortem"],
        contextRequirements: ContextRequirements(maxFiles: 2, maxTokens: 4000, includeErrorLogs: true),
        handoffRules: ["Hand off to Deployment Troubleshooter."],
        defaultModelPreference: .planningFree,
        icon: "exclamationmark.bubble",
        description: "Coordinates incident response."
    )
}
