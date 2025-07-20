import axios, { AxiosInstance } from 'axios';
import NodeCache from 'node-cache';

export interface Position {
  line: number;
  character: number;
}

export interface Location {
  uri: string;
  range: {
    start: Position;
    end: Position;
  };
}

export interface Symbol {
  name: string;
  kind: number;
  location: Location;
  containerName?: string;
}

export interface CompletionItem {
  label: string;
  kind: number;
  detail?: string;
  documentation?: string;
  insertText?: string;
}

export interface HoverInfo {
  contents: string;
  range?: {
    start: Position;
    end: Position;
  };
}

export class OneDevService {
  private client: AxiosInstance;
  private cache: NodeCache;
  private isConnected: boolean = false;

  constructor() {
    this.client = axios.create({
      baseURL: process.env.ONEDEV_URL || 'http://localhost:6610',
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Tiation-OneDev-IDE-Bridge/1.0',
      },
    });

    // Cache with 5 minute TTL
    this.cache = new NodeCache({ stdTTL: 300 });

    this.setupInterceptors();
    this.healthCheck();
  }

  private setupInterceptors() {
    // Request interceptor for authentication
    this.client.interceptors.request.use(
      (config) => {
        const token = process.env.ONEDEV_API_TOKEN;
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error) => {
        console.error('OneDev API error:', {
          url: error.config?.url,
          status: error.response?.status,
          message: error.response?.data?.message || error.message,
        });
        return Promise.reject(error);
      }
    );
  }

  private async healthCheck() {
    try {
      const response = await this.client.get('/api/server-information');
      this.isConnected = response.status === 200;
      console.log('OneDev connection established');
    } catch (error) {
      this.isConnected = false;
      console.warn('OneDev connection failed:', error instanceof Error ? error.message : 'Unknown error');
    }
  }

  public isHealthy(): boolean {
    return this.isConnected;
  }

  // Code navigation methods
  public async getHoverInfo(uri: string, position: Position): Promise<HoverInfo | null> {
    const cacheKey = `hover:${uri}:${position.line}:${position.character}`;
    const cached = this.cache.get<HoverInfo>(cacheKey);
    if (cached) return cached;

    try {
      const { projectPath, filePath } = this.parseUri(uri);
      const response = await this.client.post('/api/code-navigation/hover', {
        project: projectPath,
        file: filePath,
        line: position.line + 1, // Convert to 1-based
        column: position.character + 1,
      });

      const hoverInfo: HoverInfo = {
        contents: response.data.contents || '',
        range: response.data.range,
      };

      this.cache.set(cacheKey, hoverInfo);
      return hoverInfo;
    } catch (error) {
      console.error('Error getting hover info:', error);
      return null;
    }
  }

  public async getCompletions(uri: string, position: Position): Promise<CompletionItem[]> {
    const cacheKey = `completion:${uri}:${position.line}:${position.character}`;
    const cached = this.cache.get<CompletionItem[]>(cacheKey);
    if (cached) return cached;

    try {
      const { projectPath, filePath } = this.parseUri(uri);
      const response = await this.client.post('/api/code-navigation/completion', {
        project: projectPath,
        file: filePath,
        line: position.line + 1,
        column: position.character + 1,
      });

      const completions: CompletionItem[] = response.data.items || [];
      this.cache.set(cacheKey, completions, 60); // Shorter cache for completions
      return completions;
    } catch (error) {
      console.error('Error getting completions:', error);
      return [];
    }
  }

  public async getDefinition(uri: string, position: Position): Promise<Location[]> {
    try {
      const { projectPath, filePath } = this.parseUri(uri);
      const response = await this.client.post('/api/code-navigation/definition', {
        project: projectPath,
        file: filePath,
        line: position.line + 1,
        column: position.character + 1,
      });

      return response.data.locations || [];
    } catch (error) {
      console.error('Error getting definition:', error);
      return [];
    }
  }

  public async getReferences(uri: string, position: Position): Promise<Location[]> {
    try {
      const { projectPath, filePath } = this.parseUri(uri);
      const response = await this.client.post('/api/code-navigation/references', {
        project: projectPath,
        file: filePath,
        line: position.line + 1,
        column: position.character + 1,
        includeDeclaration: true,
      });

      return response.data.locations || [];
    } catch (error) {
      console.error('Error getting references:', error);
      return [];
    }
  }

  public async getWorkspaceSymbols(query: string): Promise<Symbol[]> {
    const cacheKey = `symbols:${query}`;
    const cached = this.cache.get<Symbol[]>(cacheKey);
    if (cached) return cached;

    try {
      const response = await this.client.get('/api/code-navigation/workspace-symbols', {
        params: { query, limit: 100 },
      });

      const symbols: Symbol[] = response.data.symbols || [];
      this.cache.set(cacheKey, symbols);
      return symbols;
    } catch (error) {
      console.error('Error getting workspace symbols:', error);
      return [];
    }
  }

  // Project management methods
  public async getProjects(): Promise<any[]> {
    const cached = this.cache.get<any[]>('projects');
    if (cached) return cached;

    try {
      const response = await this.client.get('/api/projects');
      const projects = response.data || [];
      this.cache.set('projects', projects, 60); // Cache for 1 minute
      return projects;
    } catch (error) {
      console.error('Error getting projects:', error);
      return [];
    }
  }

  public async getProject(projectPath: string): Promise<any | null> {
    const cacheKey = `project:${projectPath}`;
    const cached = this.cache.get(cacheKey);
    if (cached) return cached;

    try {
      const response = await this.client.get(`/api/projects/${encodeURIComponent(projectPath)}`);
      const project = response.data;
      this.cache.set(cacheKey, project);
      return project;
    } catch (error) {
      console.error('Error getting project:', error);
      return null;
    }
  }

  public async getBranches(projectPath: string): Promise<string[]> {
    const cacheKey = `branches:${projectPath}`;
    const cached = this.cache.get<string[]>(cacheKey);
    if (cached) return cached;

    try {
      const response = await this.client.get(`/api/projects/${encodeURIComponent(projectPath)}/branches`);
      const branches = response.data.map((branch: any) => branch.name) || [];
      this.cache.set(cacheKey, branches, 120); // Cache for 2 minutes
      return branches;
    } catch (error) {
      console.error('Error getting branches:', error);
      return [];
    }
  }

  public async getFileContent(projectPath: string, filePath: string, branch: string = 'main'): Promise<string> {
    const cacheKey = `file:${projectPath}:${filePath}:${branch}`;
    const cached = this.cache.get<string>(cacheKey);
    if (cached) return cached;

    try {
      const response = await this.client.get(`/api/projects/${encodeURIComponent(projectPath)}/files`, {
        params: {
          path: filePath,
          branch: branch,
        },
      });

      const content = response.data.content || '';
      this.cache.set(cacheKey, content);
      return content;
    } catch (error) {
      console.error('Error getting file content:', error);
      return '';
    }
  }

  // Issue management methods
  public async getIssues(projectPath: string, params: any = {}): Promise<any[]> {
    try {
      const response = await this.client.get(`/api/projects/${encodeURIComponent(projectPath)}/issues`, {
        params,
      });
      return response.data || [];
    } catch (error) {
      console.error('Error getting issues:', error);
      return [];
    }
  }

  public async createIssue(projectPath: string, issueData: any): Promise<any> {
    try {
      const response = await this.client.post(`/api/projects/${encodeURIComponent(projectPath)}/issues`, issueData);
      return response.data;
    } catch (error) {
      console.error('Error creating issue:', error);
      throw error;
    }
  }

  // Build management methods
  public async getBuilds(projectPath: string, params: any = {}): Promise<any[]> {
    try {
      const response = await this.client.get(`/api/projects/${encodeURIComponent(projectPath)}/builds`, {
        params,
      });
      return response.data || [];
    } catch (error) {
      console.error('Error getting builds:', error);
      return [];
    }
  }

  public async triggerBuild(projectPath: string, branch: string, buildSpec?: string): Promise<any> {
    try {
      const response = await this.client.post(`/api/projects/${encodeURIComponent(projectPath)}/builds`, {
        branch,
        buildSpec,
      });
      return response.data;
    } catch (error) {
      console.error('Error triggering build:', error);
      throw error;
    }
  }

  // Utility methods
  private parseUri(uri: string): { projectPath: string; filePath: string } {
    // Parse URI like "onedev://project-path/file/path"
    const match = uri.match(/^onedev:\/\/([^\/]+)\/(.+)$/);
    if (!match) {
      throw new Error(`Invalid OneDev URI: ${uri}`);
    }

    return {
      projectPath: decodeURIComponent(match[1]),
      filePath: decodeURIComponent(match[2]),
    };
  }

  public buildUri(projectPath: string, filePath: string): string {
    return `onedev://${encodeURIComponent(projectPath)}/${encodeURIComponent(filePath)}`;
  }

  // Clear cache for a project
  public clearProjectCache(projectPath: string) {
    const keys = this.cache.keys();
    const projectKeys = keys.filter(key => key.includes(projectPath));
    projectKeys.forEach(key => this.cache.del(key));
  }
}