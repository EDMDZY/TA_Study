using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FunnyGPUInstance : MonoBehaviour
{
    [SerializeField]
    private GameObject _instanceGo;//初实例化对你
    [SerializeField]
    private int _instanceCount;//实例化个数
    [SerializeField]
    private bool _bRandPos = false;
    // Start is called before the first frame update
    void Start()
    {
        //与buffer交换数据
        MaterialPropertyBlock mpb = new MaterialPropertyBlock();
       

        for (int i = 0; i < _instanceCount; i++)
        {
            Vector3 pos = new Vector3(i * 1.5f, 0, 0);
            GameObject pGO = GameObject.Instantiate<GameObject>(_instanceGo);
            pGO.transform.SetParent(gameObject.transform);
            if (_bRandPos)
            {
                pGO.transform.localPosition = Random.insideUnitSphere * 10.0f;
            }
            else
            {
                pGO.transform.localPosition = pos;
            }

            //随机每个对象的颜色
            mpb.SetColor("_Color", new Color(Random.Range(0f, 1f), Random.Range(0f, 1f), Random.Range(0f, 1f), 1.0f));
            mpb.SetFloat("_Phi", Random.Range(-40f, 40f));
            mpb.SetFloat("_Speed", Random.Range(-10f, 10f));
            mpb.SetFloat("_A", Random.Range(-10f, 10f));

            MeshRenderer meshRenderer = pGO.GetComponent<MeshRenderer>();
            if (meshRenderer != null)
            {
                meshRenderer.SetPropertyBlock(mpb);
            }

        }


    }
}
