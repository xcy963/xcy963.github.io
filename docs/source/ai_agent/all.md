# agent

## 关于vscode remote ssh的代理问题

- 在控制面板输入`remote ssh settings`,然后注入,就可以正常使用了
- 记得安装clash,我比较喜欢[clash linux](https://github.com/nelvko/clash-for-linux-install)
```json
{
  "http.proxy": "http://127.0.0.1:7890",
  "http.proxySupport": "override",
  "http.proxyStrictSSL": true,
}
```

- 这个网页ui打不开,使用控制端口
- 这里可以使用ss查询
```bash
(react_infer_env) [guest@yuanshihao-manjaro DeepResearch]$ ss -lntp 
State     Recv-Q    Send-Q       Local Address:Port        Peer Address:Port   Process                                         
LISTEN    0         4096             127.0.0.1:14890            0.0.0.0:*                                                      
LISTEN    0         128              127.0.0.1:8888             0.0.0.0:*                                                      
LISTEN    0         4096             127.0.0.1:7890             0.0.0.0:*       users:(("mihomo",pid=4092404,fd=6))            
LISTEN    0         511              127.0.0.1:5192             0.0.0.0:*       users:(("node",pid=4078934,fd=44))             
```

- 如果想要知道clash在哪个端口提供代理服务
```bash

```


## transformer版本的报错

```{note}
直接运行会有trasformer版本的报错问题,使用`pip install git+https://github.com/huggingface/transformers.git`
- 安装的版本是`pip install transformers==4.57.3`,为了不出现兼容性问题,没安太新
```

## 关于复现的时候的data集的路径问题
- 似乎是他没有使用mkdir创建,我加上了

## 关于他使用的搜索api

## 关于sandbox

- 使用poetry配置环境
- 然后还需要配置下python的环境,比如使用
```bash
cd runtime/python
bash install-python-runtime.sh
```
- `make run-online`就可以跑了

## 关于模型超上下文
- 现在最大的上下文设置是64k,

## 关于模型的整个流程

```{note}
执行流程

数据入口：run_multi_react.py 读取你的问题列表（JSON/JSONL），支持数据分片（--total_splits/--worker_split），每个问题会跑 roll_out_count 轮独立“解答尝试”，输出到对应的 iter{i}.jsonl。
调度与并发：线程池并行提交任务（默认 max_workers=20），对每个问题轮次封装成任务，指定使用的 vLLM 端口（当前只有 6001）。
Agent 核心：react_agent.py 的 MultiTurnReactAgent._run 负责单个问题的推理。系统提示在 prompt.py，定义了可用工具（search/visit/google_scholar/PythonInterpreter/parse_file 等）和输出格式（最终答案必须 <answer></answer>）。
多轮原因：这是典型 ReAct 流程——LLM 先思考/规划，可能输出 <tool_call>，代理实际执行工具（网页搜索/抓取/跑 Python 等），把 <tool_response> 作为新一轮“用户”消息喂回，再让 LLM 继续。循环直到出现 <answer> 或触发限制。
终止条件：每轮消耗 MAX_LLM_CALL_PER_RUN（默认 100）、最长 150 分钟、或上下文 token 超出阈值（count_tokens 检测，超限时强制收尾）。若 <answer> 未出现且达上限，会写入失败/超时信息。
输入后如何推理（逐步）

构造对话：system + user(question)。
调用本地 vLLM（call_server，端口 6001），LLM 产出文本，可能包含 <tool_call>。
若有 <tool_call>：解析 JSON 或 Python 代码，调用对应工具（search/visit/scholar/parse_file/PythonInterpreter），得到结果包装成 <tool_response>，追加为下一轮用户消息。
重复调用 vLLM，直至返回带 <answer> 的回复；否则继续规划/调用工具。
记录所有消息、预测、终止原因写回对应 rollout 文件。
总体逻辑：多轮是为了在信息不足时让 LLM先查找/计算、再综合；多次 rollout 则是为同一问题生成多条独立解答以提高覆盖/鲁棒性。
```

- 他内部是有调度的,vllm支持不同的卡上跑不同的模型,然后分给不同的端口,之后就是每次任务封装为`question`和`answer`,然后分配给端口
- 