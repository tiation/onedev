import express from 'express';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';

import { GitService } from './services/GitService';
import { OneDevService } from './services/OneDevService';
import { SupabaseService } from './services/SupabaseService';
import { AuthService } from './services/AuthService';
import { WebSocketHandler } from './handlers/WebSocketHandler';
import { GitRouter } from './routes/git';
import { ProjectRouter } from './routes/projects';
import { CodeNavigationRouter } from './routes/code-navigation';

// Load environment variables
dotenv.config();

class IDEBridgeServer {
  private app: express.Application;
  private server: any;
  private wss: WebSocketServer;
  private gitService: GitService;
  private oneDevService: OneDevService;
  private supabaseService: SupabaseService;
  private authService: AuthService;
  private wsHandler: WebSocketHandler;

  constructor() {
    this.app = express();
    this.server = createServer(this.app);
    this.wss = new WebSocketServer({ server: this.server });
    
    this.initializeServices();
    this.setupMiddleware();
    this.setupRoutes();
    this.setupWebSockets();
  }

  private initializeServices() {
    this.supabaseService = new SupabaseService();
    this.oneDevService = new OneDevService();
    this.gitService = new GitService();
    this.authService = new AuthService();
    this.wsHandler = new WebSocketHandler(
      this.oneDevService,
      this.gitService,
      this.supabaseService
    );
  }

  private setupMiddleware() {
    // Security middleware
    this.app.use(helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: ["'self'", "data:", "https:"],
          connectSrc: ["'self'", "ws:", "wss:", process.env.SUPABASE_URL || ""],
        },
      },
    }));

    // Rate limiting
    const limiter = rateLimit({
      windowMs: 15 * 60 * 1000, // 15 minutes
      max: 1000, // limit each IP to 1000 requests per windowMs
      message: 'Too many requests from this IP, please try again later.',
    });
    this.app.use(limiter);

    // CORS
    this.app.use(cors({
      origin: [
        'http://localhost:3000',
        'https://localhost:3000',
        process.env.ONEDEV_URL || 'http://localhost:6610',
        process.env.ALLOWED_ORIGINS?.split(',') || [],
      ].filter(Boolean),
      credentials: true,
    }));

    // Compression and logging
    this.app.use(compression());
    this.app.use(morgan('combined'));

    // Body parsing
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true }));

    // Authentication middleware for API routes
    this.app.use('/api', this.authService.authenticate.bind(this.authService));
  }

  private setupRoutes() {
    // Health check
    this.app.get('/health', (req, res) => {
      res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        version: process.env.npm_package_version || '1.0.0',
        services: {
          onedev: this.oneDevService.isHealthy(),
          supabase: this.supabaseService.isHealthy(),
          git: this.gitService.isHealthy(),
        },
      });
    });

    // API routes
    this.app.use('/api/git', new GitRouter(this.gitService, this.oneDevService).router);
    this.app.use('/api/projects', new ProjectRouter(this.oneDevService, this.supabaseService).router);
    this.app.use('/api/code-navigation', new CodeNavigationRouter(this.oneDevService, this.gitService).router);

    // IDE-specific endpoints
    this.app.get('/api/ide/capabilities', (req, res) => {
      res.json({
        features: [
          'git-operations',
          'code-navigation',
          'symbol-search',
          'issue-integration',
          'pull-request-management',
          'real-time-collaboration',
          'build-integration',
          'code-review',
        ],
        protocols: ['http', 'websocket'],
        authentication: ['jwt', 'oauth'],
      });
    });

    // VS Code Language Server Protocol endpoint
    this.app.post('/api/lsp/:method', async (req, res) => {
      try {
        const { method } = req.params;
        const result = await this.handleLSPRequest(method, req.body);
        res.json(result);
      } catch (error) {
        res.status(500).json({
          error: 'LSP request failed',
          message: error instanceof Error ? error.message : 'Unknown error',
        });
      }
    });

    // Error handling
    this.app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
      console.error('Server error:', err);
      res.status(500).json({
        error: 'Internal server error',
        message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong',
      });
    });

    // 404 handler
    this.app.use((req, res) => {
      res.status(404).json({
        error: 'Not found',
        path: req.path,
      });
    });
  }

  private setupWebSockets() {
    this.wss.on('connection', (ws, request) => {
      console.log('New WebSocket connection established');
      this.wsHandler.handleConnection(ws, request);
    });
  }

  private async handleLSPRequest(method: string, params: any) {
    // Language Server Protocol request handling
    switch (method) {
      case 'initialize':
        return {
          capabilities: {
            textDocumentSync: 1,
            hoverProvider: true,
            completionProvider: {
              resolveProvider: true,
              triggerCharacters: ['.', ':', '<'],
            },
            signatureHelpProvider: {
              triggerCharacters: ['(', ','],
            },
            definitionProvider: true,
            referencesProvider: true,
            documentHighlightProvider: true,
            documentSymbolProvider: true,
            workspaceSymbolProvider: true,
            codeActionProvider: true,
            documentFormattingProvider: true,
            renameProvider: true,
          },
        };

      case 'textDocument/hover':
        return this.oneDevService.getHoverInfo(params.textDocument.uri, params.position);

      case 'textDocument/completion':
        return this.oneDevService.getCompletions(params.textDocument.uri, params.position);

      case 'textDocument/definition':
        return this.oneDevService.getDefinition(params.textDocument.uri, params.position);

      case 'textDocument/references':
        return this.oneDevService.getReferences(params.textDocument.uri, params.position);

      case 'workspace/symbol':
        return this.oneDevService.getWorkspaceSymbols(params.query);

      default:
        throw new Error(`Unsupported LSP method: ${method}`);
    }
  }

  public start() {
    const port = process.env.PORT || 8080;
    
    this.server.listen(port, () => {
      console.log(`🚀 Tiation OneDev IDE Bridge server started on port ${port}`);
      console.log(`🌐 Health check: http://localhost:${port}/health`);
      console.log(`🔌 WebSocket endpoint: ws://localhost:${port}`);
      console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
    });

    // Graceful shutdown
    process.on('SIGTERM', () => {
      console.log('SIGTERM received, shutting down gracefully');
      this.server.close(() => {
        console.log('Server closed');
        process.exit(0);
      });
    });

    process.on('SIGINT', () => {
      console.log('SIGINT received, shutting down gracefully');
      this.server.close(() => {
        console.log('Server closed');
        process.exit(0);
      });
    });
  }
}

// Start the server
if (require.main === module) {
  const server = new IDEBridgeServer();
  server.start();
}

export default IDEBridgeServer;